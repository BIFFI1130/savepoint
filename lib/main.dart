import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/ads/ad_consent_service.dart';
import 'core/config/env.dart';
import 'core/notifications/release_reminder_service.dart';
import 'core/preferences/content_filter_prefs.dart';
import 'core/subscription/subscription_service.dart';
import 'core/supabase/supabase_client.dart';
import 'features/game_log/data/log_repository.dart';
import 'features/game_log/domain/game_log.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initSupabase();
  } catch (error, stackTrace) {
    // 起動時の初期化に失敗すると画面が真っ白のまま何も表示されなくなるため、
    // 原因を確認できるよう最低限のエラー画面を出す。
    debugPrint('initSupabase failed: $error\n$stackTrace');
    runApp(_StartupErrorApp(error: error));
    return;
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // デバッグ実行中はCrashlyticsへの送信を無効化し、開発中のエラーでノイズを
  // 増やさないようにする（TestFlight/Firebase配信のリリースビルドでのみ収集する）。
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
    !kDebugMode,
  );
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: true);
    return true;
  };

  final sharedPreferences = await SharedPreferences.getInstance();

  // iOSのホーム画面ウィジェット（BacklogWidgetExtension）とApp Group経由で
  // データを共有するために必要（Androidでは無視されるだけなので分岐不要）。
  await HomeWidget.setAppGroupId('group.com.biffi.savepoint');

  // Googleサインインの初期化は起動時に一度だけ行う必要がある。クライアントID
  // 未設定（ローカル開発でenv/dev.jsonに追加していない等）の場合はスキップし、
  // Googleサインインボタン自体がエラーを返すだけでアプリの起動はブロックしない。
  if (Env.googleWebClientId.isNotEmpty) {
    try {
      await GoogleSignIn.instance.initialize(
        clientId: Env.googleIosClientId.isNotEmpty
            ? Env.googleIosClientId
            : null,
        serverClientId: Env.googleWebClientId,
      );
    } catch (error, stackTrace) {
      debugPrint('GoogleSignIn initialize failed: $error\n$stackTrace');
    }
  }

  // 広告配信の同意確認（UMP）が完了してからAdMob SDKを初期化する。
  // 失敗しても（オフライン等）アプリの起動自体はブロックしない。
  await const AdConsentService().requestConsentAndInitialize();

  // RevenueCat SDKの初期化。APIキー未設定時は内部でスキップされ、
  // 課金機能全体が「未購入」として安全に無効化される。
  await SubscriptionService.configure();

  // 「遊びたい」の未発売ゲームの発売日通知は、端末側にしか予約情報が
  // 残らない（再インストール・端末変更等で消える）ため起動のたびに予約し直す。
  // 未ログイン・取得失敗時は何もせず、アプリの起動自体はブロックしない。
  unawaited(_rescheduleReleaseReminders());

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const SavePointApp(),
    ),
  );
}

Future<void> _rescheduleReleaseReminders() async {
  try {
    final logs = await LogRepository().fetchMyLogs();
    final releaseReminderService = ReleaseReminderService();
    final now = DateTime.now();
    for (final entry in logs) {
      if (entry.log.status != GameLogStatus.wantToPlay) continue;
      final releaseDate = entry.game.firstReleaseDate;
      if (releaseDate == null || !releaseDate.isAfter(now)) continue;
      await releaseReminderService.scheduleForGame(
        gameId: entry.game.id,
        title: entry.game.displayName,
        releaseDate: releaseDate,
      );
    }
  } catch (error, stackTrace) {
    debugPrint('release reminder reschedule failed: $error\n$stackTrace');
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    '起動に失敗しました',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text('$error', textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
