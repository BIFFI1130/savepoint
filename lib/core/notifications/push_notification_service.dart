import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../supabase/supabase_client.dart';

/// 新しいフォロワー（誰かに新しくフォローされたこと）をサーバー起点の
/// プッシュ通知（FCM/APNs）で受け取るための登録・解除・受信表示をまとめて扱う。
///
/// 積みゲー/発売日リマインダー（[BacklogReminderService]・[ReleaseReminderService]、
/// 端末内で完結するローカル通知）とは異なり、これはサーバー
/// （notify-new-follower Edge Function）から送信される通知を受け取る。
/// フォアグラウンド受信時の表示にはflutter_local_notificationsをそのまま流用する
/// （FCMはフォアグラウンド中は自動でシステム通知を出さないため）。
///
/// 有効・無効は、アプリ独自のON/OFFフラグを持たず、常にOS側（端末の通知設定）の
/// 許可状態をそのまま反映する（[authorizationStatus]）。アプリ内で「無効にする」
/// 操作は提供せず、無効にしたい場合は端末の設定アプリから行ってもらう
/// （[openSystemSettings]でその画面を直接開ける）。
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

  /// OS側（端末の通知設定）の許可状態を、許可ダイアログを出さずに確認する。
  Future<ph.PermissionStatus> authorizationStatus() =>
      ph.Permission.notification.status;

  /// 端末の設定アプリの、本アプリの通知設定画面を直接開く。
  Future<void> openSystemSettings() => ph.openAppSettings();

  /// まだOSに一度も許可を求めていない場合のみ、許可ダイアログを表示する
  /// （iOSは一度拒否/許可が確定すると、二度目以降はダイアログを出せず即座に
  /// 同じ結果が返るだけのため、その場合は[openSystemSettings]で設定アプリへ誘導する）。
  /// 許可が得られればトークンを登録する。
  Future<bool> requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    if (granted) {
      await _ensureLocalInitialized();
      await _registerToken();
    }
    return granted;
  }

  Future<void> _registerToken() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // iOSでは、FCMトークンを取得する前にAPNsトークンが端末に設定されている必要が
        // あるが、requestPermission()の直後はまだiOS側の登録が終わっておらずAPNsトークンが
        // 未設定のことがある。その状態でgetToken()を呼ぶと例外が発生し、この関数は
        // 何もせずに（下のcatchで握りつぶされて）終わってしまう——許可自体は得られている
        // ため設定画面の表示は有効に見えるが、実際にはdevice_tokensに何も登録されない
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

  /// [token]をSupabase上の自分のトークン一覧から削除する。
  Future<void> _clearToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await supabase.from('device_tokens').delete().eq('token', token);
      }
    } catch (error, stackTrace) {
      debugPrint('push token clear failed: $error\n$stackTrace');
    }
  }

  /// アプリ起動時、OS側の許可状態とdevice_tokensの登録状態を同期する
  /// （許可されていればトークンを最新化、許可されていなければ登録済みトークンを削除）。
  /// 再インストール・機種変更・端末設定での許可取り消し等、いずれの場合にも
  /// アプリを開き直せば正しい状態に揃う。
  Future<void> syncWithSystemPermission() async {
    final status = await authorizationStatus();
    if (status.isGranted || status.isLimited || status.isProvisional) {
      await _ensureLocalInitialized();
      await _registerToken();
    } else if (status.isDenied || status.isPermanentlyDenied || status.isRestricted) {
      await _clearToken();
    }
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

/// 設定画面の表示用。端末側の通知許可状態（OS設定に依存、アプリ独自のON/OFFは持たない）。
/// 端末の設定画面から変更して戻ってきた場合に再取得できるよう、呼び出し側で
/// `ref.invalidate(pushAuthorizationStatusProvider)` を呼ぶこと。
final pushAuthorizationStatusProvider = FutureProvider<ph.PermissionStatus>((ref) async {
  return ref.watch(pushNotificationServiceProvider).authorizationStatus();
});
