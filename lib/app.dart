import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'core/ads/launch_ad_service.dart';
import 'core/deep_links/deep_link_service.dart';
import 'core/home_widget/backlog_widget_service.dart';
import 'core/notifications/aged_backlog_reminder_service.dart';
import 'core/notifications/memories_reminder_service.dart';
import 'core/notifications/monthly_recap_reminder_service.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/notifications/streak_reminder_service.dart';
import 'core/router/app_router.dart';
import 'core/streak/app_open_streak_service.dart';
import 'core/subscription/subscription_providers.dart';
import 'core/subscription/subscription_service.dart';
import 'core/supabase/supabase_client.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_service.dart';
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

    // アプリ起動ストリーク（記録の有無を問わない、単純な連続起動日数）。
    unawaited(ref.read(appOpenStreakServiceProvider).ensureTodayCounted());

    // 積みゲーの中で発売が一番近い作品を、Androidのホーム画面ウィジェットに同期する。
    // myLogsProviderはHomeShellのIndexedStack上で常に監視され続けるため、
    // 更新箇所ごとに個別に呼び出す必要がなく、ここ1箇所で全ての変更を捕捉できる。
    // build()内のref.listenはfireImmediatelyに対応していないため、
    // 登録前に確定していた（＝アプリ起動直後の）データを取りこぼさないよう
    // initStateでlistenManual(fireImmediately: true)を使う。
    ref.listenManual(myLogsProvider, (previous, next) {
      next.whenData((logs) {
        const BacklogWidgetService().sync(logs);
        unawaited(ref.read(streakReminderServiceProvider).syncSchedule(logs));
        unawaited(
          ref.read(agedBacklogReminderServiceProvider).syncSchedule(logs),
        );
        unawaited(ref.read(memoriesReminderServiceProvider).syncSchedule(logs));
      });
    }, fireImmediately: true);

    // 月末ふりかえりのローカル通知（有効な場合、次回分が確実に積まれているようにする）。
    unawaited(
      ref.read(monthlyRecapReminderServiceProvider).ensureScheduled(),
    );

    // 新しいフォロワーのプッシュ通知（サーバー起点）の受信・タップ処理。
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

    // 起動時広告（1日1回、サブスク加入者には表示しない）。「遊んだ／遊びたい」を
    // 記録するフロー自体には一切関与しない、起動直後のみの広告枠。
    // 未ログイン（オンボーディング中）はまだ記録体験に至っていないので対象外とする。
    if (ref.read(currentUserProvider) != null &&
        !ref.read(isAdFreeProvider)) {
      unawaited(ref.read(launchAdServiceProvider).maybeShow());
    }
  }

  @override
  void dispose() {
    _widgetClickSubscription?.cancel();
    _foregroundPushSubscription?.cancel();
    _pushTapSubscription?.cancel();
    _pushTokenRefreshSubscription?.cancel();
    super.dispose();
  }

  /// サーバー起点のプッシュ通知のタップを受け取り、通知の種類（data.type）に応じて
  /// 適切な画面へ遷移する（ホーム画面ウィジェットのタップ処理と同じ考え方）。
  /// - new_follower: フォローしてきたユーザーのプロフィール画面
  /// - new_review: レビューが投稿されたゲームの詳細画面
  /// - weekly_digest: ホーム画面（タイムラインサブタブへの直接遷移は未対応）
  void _handlePushTap(RemoteMessage? message) {
    final data = message?.data;
    if (data == null) return;
    try {
      switch (data['type']) {
        case 'new_follower':
          final userId = data['user_id'];
          if (userId != null) ref.read(routerProvider).go('/users/$userId');
        case 'new_review':
          final gameId = data['game_id'];
          if (gameId != null) ref.read(routerProvider).go('/games/$gameId');
        case 'weekly_digest':
          ref.read(routerProvider).go('/home');
      }
    } catch (error, stackTrace) {
      debugPrint('プッシュ通知タップの処理に失敗しました: $error\n$stackTrace');
    }
  }

  /// カスタムURLスキーム（`savepoint://`）経由のリンクを受け取る。
  /// - `savepoint://reset-password?code=...`: パスワード再設定メールのリンク。
  ///   セッションを確立してから再設定画面へ遷移する。
  /// - `savepoint://user/{userId}`: プロフィール共有リンク（QRコード/招待リンク）。
  ///   該当ユーザーのプロフィール画面へ遷移する。
  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.scheme != 'savepoint') return;
    try {
      if (uri.host == 'reset-password') {
        await supabase.auth.getSessionFromUrl(uri);
        ref.read(routerProvider).go('/reset-password');
      } else if (uri.host == 'user' && uri.pathSegments.isNotEmpty) {
        ref.read(routerProvider).go('/users/${uri.pathSegments.first}');
      }
    } catch (error, stackTrace) {
      debugPrint('ディープリンクの処理に失敗しました: $error\n$stackTrace');
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
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
    );
  }
}
