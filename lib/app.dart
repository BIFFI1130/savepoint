import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'core/deep_links/deep_link_service.dart';
import 'core/home_widget/backlog_widget_service.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/router/app_router.dart';
import 'core/subscription/subscription_service.dart';
import 'core/supabase/supabase_client.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/game_log/presentation/providers/log_providers.dart';

class SavePointApp extends ConsumerStatefulWidget {
  const SavePointApp({super.key});

  @override
  ConsumerState<SavePointApp> createState() => _SavePointAppState();
}

class _SavePointAppState extends ConsumerState<SavePointApp> {
  StreamSubscription<Uri?>? _widgetClickSubscription;
  StreamSubscription<RemoteMessage>? _foregroundPushSubscription;
  StreamSubscription<RemoteMessage>? _pushTapSubscription;
  StreamSubscription<String>? _pushTokenRefreshSubscription;

  @override
  void initState() {
    super.initState();
    DeepLinkService(_handleDeepLink).init();
    _widgetClickSubscription = HomeWidget.widgetClicked.listen(
      _handleWidgetTap,
    );
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetTap);

    // 積みゲーの中で発売が一番近い作品を、Androidのホーム画面ウィジェットに同期する。
    // myLogsProviderはHomeShellのIndexedStack上で常に監視され続けるため、
    // 更新箇所ごとに個別に呼び出す必要がなく、ここ1箇所で全ての変更を捕捉できる。
    // build()内のref.listenはfireImmediatelyに対応していないため、
    // 登録前に確定していた（＝アプリ起動直後の）データを取りこぼさないよう
    // initStateでlistenManual(fireImmediately: true)を使う。
    ref.listenManual(myLogsProvider, (previous, next) {
      next.whenData((logs) => const BacklogWidgetService().sync(logs));
    }, fireImmediately: true);

    // フォロー中ユーザーの新着プッシュ通知（サーバー起点）の受信・タップ処理。
    // 通知自体が無効（未許可）な端末では単にトークンが無いだけで、これらの
    // リスナー登録自体は無害なので常に行っておく。
    final pushService = ref.read(pushNotificationServiceProvider);
    unawaited(pushService.reregisterIfEnabled());
    _foregroundPushSubscription =
        FirebaseMessaging.onMessage.listen(pushService.showForeground);
    _pushTapSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(_handlePushTap);
    FirebaseMessaging.instance.getInitialMessage().then(_handlePushTap);
    _pushTokenRefreshSubscription = pushService.onTokenRefresh.listen(
      (_) => pushService.reregisterIfEnabled(),
    );
  }

  @override
  void dispose() {
    _widgetClickSubscription?.cancel();
    _foregroundPushSubscription?.cancel();
    _pushTapSubscription?.cancel();
    _pushTokenRefreshSubscription?.cancel();
    super.dispose();
  }

  /// フォロー中ユーザーの新着プッシュ通知のタップを受け取り、該当ゲームの
  /// 詳細画面へ遷移する（ホーム画面ウィジェットのタップ処理と同じ考え方）。
  void _handlePushTap(RemoteMessage? message) {
    final gameId = message?.data['game_id'];
    if (gameId == null) return;
    try {
      ref.read(routerProvider).go('/games/$gameId');
    } catch (error, stackTrace) {
      debugPrint('プッシュ通知タップの処理に失敗しました: $error\n$stackTrace');
    }
  }

  /// パスワード再設定メールのリンク（`savepoint://reset-password?code=...`）を受け取り、
  /// セッションを確立してから再設定画面へ遷移する。それ以外のリンクは無視する。
  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.scheme != 'savepoint' || uri.host != 'reset-password') return;
    try {
      await supabase.auth.getSessionFromUrl(uri);
      ref.read(routerProvider).go('/reset-password');
    } catch (error, stackTrace) {
      debugPrint('パスワード再設定リンクの処理に失敗しました: $error\n$stackTrace');
    }
  }

  /// ホーム画面ウィジェット（積みゲーの発売日カウントダウン）のタップを受け取り、
  /// 該当ゲームの詳細画面へ遷移する。ゲームが無い状態でのタップは`savepoint://home`。
  void _handleWidgetTap(Uri? uri) {
    if (uri == null || uri.scheme != 'savepoint') return;
    try {
      if (uri.host == 'game' && uri.pathSegments.isNotEmpty) {
        ref.read(routerProvider).go('/games/${uri.pathSegments.first}');
      } else if (uri.host == 'home') {
        ref.read(routerProvider).go('/home');
      }
    } catch (error, stackTrace) {
      debugPrint('ウィジェットタップの処理に失敗しました: $error\n$stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // ログイン中のSupabaseユーザーIDをRevenueCatに紐付け、同一アカウントの
    // 再インストール・機種変更でも購入権利が引き継がれるようにする。
    ref.listen(currentUserProvider, (previous, next) {
      if (next != null) {
        SubscriptionService.logIn(next.id);
      } else if (previous != null) {
        SubscriptionService.logOut();
      }
    });

    return MaterialApp.router(
      title: 'SavePoint',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ja', 'JP'),
      supportedLocales: const [Locale('ja', 'JP')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
