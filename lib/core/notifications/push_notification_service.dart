import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../supabase/supabase_client.dart';

const _enabledKey = 'follow_push_enabled';

/// 新しいフォロワー（誰かに新しくフォローされたこと）をサーバー起点の
/// プッシュ通知（FCM/APNs）で受け取るための登録・解除・受信表示をまとめて扱う。
///
/// 積みゲー/発売日リマインダー（[BacklogReminderService]・[ReleaseReminderService]、
/// 端末内で完結するローカル通知）とは異なり、これはサーバー
/// （notify-new-follower Edge Function）から送信される通知を受け取る。
/// フォアグラウンド受信時の表示にはflutter_local_notificationsをそのまま流用する
/// （FCMはフォアグラウンド中は自動でシステム通知を出さないため）。
class PushNotificationService {
  PushNotificationService();

  final _localPlugin = FlutterLocalNotificationsPlugin();
  bool _localInitialized = false;

  Future<void> _ensureLocalInitialized() async {
    if (_localInitialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localPlugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
    _localInitialized = true;
  }

  /// 明示的にOFFにされていない限りtrue（初期値はON）。
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  /// 通知の許可を求め、許可が得られればFCMトークンを取得してSupabaseに登録する。
  /// 許可が得られなかった場合はfalseを返し、設定側の状態も有効にしない。
  Future<bool> enable() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!granted) return false;

    await _ensureLocalInitialized();
    await _registerToken();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    return true;
  }

  /// 通知を無効化し、Supabase上の自分のトークンも削除する。
  Future<void> disable() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await supabase.from('device_tokens').delete().eq('token', token);
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (error, stackTrace) {
      debugPrint('push notification disable failed: $error\n$stackTrace');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
  }

  Future<void> _registerToken() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // iOSでは、FCMトークンを取得する前にAPNsトークンが端末に設定されている必要が
        // あるが、requestPermission()の直後はまだiOS側の登録が終わっておらずAPNsトークンが
        // 未設定のことがある。その状態でgetToken()を呼ぶと例外が発生し、この関数は
        // 何もせずに（下のcatchで握りつぶされて）終わってしまう——許可自体は得られている
        // ため設定画面のトグルは有効に見えるが、実際にはdevice_tokensに何も登録されない
        // という紛らわしい状態になる。そのため、APNsトークンが設定されるまで最大20秒
        // ポーリングで待つ。
        var apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        var attempts = 0;
        while (apnsToken == null && attempts < 20) {
          await Future.delayed(const Duration(seconds: 1));
          apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          attempts++;
        }
        if (apnsToken == null) {
          // 実機で発生した場合にXcodeコンソールが無くても原因追跡できるよう、
          // Crashlyticsへ非致命的エラーとして記録する（fatal: falseなので
          // クラッシュ扱いにはならない）。
          unawaited(
            FirebaseCrashlytics.instance.recordError(
              'push token registration failed: APNs token timeout after 20s',
              StackTrace.current,
              fatal: false,
            ),
          );
          debugPrint('APNsトークンの取得がタイムアウトしました。');
          return;
        }
      }

      final token = await FirebaseMessaging.instance.getToken();
      final userId = supabase.auth.currentUser?.id;
      if (token == null || userId == null) {
        unawaited(
          FirebaseCrashlytics.instance.recordError(
            'push token registration failed: getToken()=$token userId=$userId',
            StackTrace.current,
            fatal: false,
          ),
        );
        return;
      }
      await supabase.from('device_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'token');
    } catch (error, stackTrace) {
      debugPrint('push token registration failed: $error\n$stackTrace');
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          reason: 'push token registration failed',
          fatal: false,
        ),
      );
    }
  }

  /// アプリ起動時、通知が既に有効な場合にトークンを最新化する
  /// （再インストール・機種変更等でトークンが変わっている場合に備える）。
  Future<void> reregisterIfEnabled() async {
    if (!await isEnabled()) return;
    await _registerToken();
  }

  Stream<String> get onTokenRefresh => FirebaseMessaging.instance.onTokenRefresh;

  /// フォアグラウンド受信時に端末内通知として表示する。
  Future<void> showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _ensureLocalInitialized();
    await _localPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'new_follower',
          '新しいフォロワー',
          channelDescription: '誰かに新しくフォローされたときに通知します',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService();
});

/// 設定画面のトグル表示用。有効・無効を切り替えたら
/// `ref.invalidate(followPushEnabledProvider)` で再取得する。
final followPushEnabledProvider = FutureProvider<bool>((ref) async {
  return ref.watch(pushNotificationServiceProvider).isEnabled();
});
