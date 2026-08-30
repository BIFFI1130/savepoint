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
import 'core/preferences/content_filter_prefs.dart';
import 'core/router/app_router.dart';
import 'core/streak/app_open_streak_service.dart';
import 'core/subscription/subscription_providers.dart';
import 'core/subscription/subscription_service.dart';
import 'core/supabase/supabase_client.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_service.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/calendar/presentation/providers/calendar_providers.dart';
import 'features/collections/presentation/providers/collection_providers.dart';
import 'features/favorites/presentation/providers/favorite_providers.dart';
import 'features/game_log/presentation/providers/log_providers.dart';
import 'features/social/presentation/providers/social_providers.dart';

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

    // 「本日発売」ウィジェットは自分の「遊びたい」リストに関わらず全ユーザー向けの
    // 本日発売作品を表示するため、myLogsProviderとは独立に起動時1回だけ同期する
    // （日付が変わるまで内容は変わらないため、ウィジェット自体の6時間ごとの
    // 定期更新と合わせれば十分）。
    unawaited(_syncTodayReleasesWidget());

    // 新しいフォロワーのプッシュ通知（サーバー起点）の受信・タップ処理。
    // 通知自体が無効（未許可）な端末では単にトークンが無いだけで、これらの
    // リスナー登録自体は無害なので常に行っておく。
    final pushService = ref.read(pushNotificationServiceProvider);
    unawaited(pushService.syncWithSystemPermission());
    _foregroundPushSubscription = FirebaseMessaging.onMessage.listen((
      message,
    ) {
      _invalidateProvidersForPush(message);
      pushService.showForeground(message);
    });
    _pushTapSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(_handlePushTap);
    FirebaseMessaging.instance.getInitialMessage().then(_handlePushTap);
    _pushTokenRefreshSubscription = pushService.onTokenRefresh.listen(
      (_) => pushService.syncWithSystemPermission(),
    );

    // 起動時広告（1日1回、サブスク加入者には表示しない）。「遊んだ／遊びたい」を
    // 記録するフロー自体には一切関与しない、起動直後のみの広告枠。
    // 未ログイン（オンボーディング中）はまだ記録体験に至っていないので対象外とする。
    if (ref.read(currentUserProvider) != null &&
        !ref.read(isAdFreeProvider)) {
      unawaited(ref.read(launchAdServiceProvider).maybeShow());
    }
  }

  /// 「本日発売」ウィジェット向けに、全ユーザー向けの本日発売作品を取得して同期する。
  Future<void> _syncTodayReleasesWidget() async {
    try {
      final contentFilterPrefs = ref.read(contentFilterPrefsProvider);
      final today = DateTime.now();
      final request = (
        rangeStart: DateTime(today.year, today.month, today.day),
        days: 1,
        filter: (
          platforms: const <String>{},
          genres: const <String>{},
          includeAdult: contentFilterPrefs.includeAdult,
          includeIndie: contentFilterPrefs.includeIndie,
          matchAllGenres: false,
        ),
      );
      final games =
          await ref.read(calendarRangeReleasesProvider(request).future);
      await const BacklogWidgetService().syncTodayReleases(games);
    } catch (error, stackTrace) {
      debugPrint('本日発売ウィジェットの同期に失敗しました: $error\n$stackTrace');
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
  /// - new_like: いいねされた記録のゲーム詳細画面
  void _handlePushTap(RemoteMessage? message) {
    _invalidateProvidersForPush(message);
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
        case 'new_like':
          final gameId = data['game_id'];
          if (gameId != null) ref.read(routerProvider).go('/games/$gameId');
      }
    } catch (error, stackTrace) {
      debugPrint('プッシュ通知タップの処理に失敗しました: $error\n$stackTrace');
    }
  }

  /// サーバー起点のプッシュ通知は、フォロー・いいね・レビューなど他ユーザーの
  /// 操作によって届くため、通知を受け取った時点（フォアグラウンド表示時・タップ時
  /// どちらでも）で該当データのプロバイダを無効化し、次にその画面を開いたときに
  /// 再取得を実行させる。これが無いと、アプリを再起動するまでフォロワー数・
  /// フォロワー一覧などが更新されない（実機で確認済みの不具合）。
  void _invalidateProvidersForPush(RemoteMessage? message) {
    if (message?.data['type'] == 'new_follower') {
      ref.invalidate(followersListProvider);
    }
  }

  /// カスタムURLスキーム（`savepoint://`）経由のリンクを受け取る。
  /// - `savepoint://reset-password?code=...`: パスワード再設定メールのリンク。
  ///   セッションを確立してから再設定画面へ遷移する。
  /// - `savepoint://email-confirmed?code=...`: 新規登録時のメール確認リンク。
  ///   セッションを確立し、通常のログイン後と同じ導線（オンボーディング等）に乗せる。
  /// - `savepoint://user/{userId}`: プロフィール共有リンク（QRコード/招待リンク）。
  ///   該当ユーザーのプロフィール画面へ遷移する。
  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.scheme != 'savepoint') return;
    try {
      if (uri.host == 'reset-password') {
        await supabase.auth.getSessionFromUrl(uri);
        ref.read(routerProvider).go('/reset-password');
      } else if (uri.host == 'email-confirmed') {
        await supabase.auth.getSessionFromUrl(uri);
        ref.read(routerProvider).go('/home');
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

      // ログインユーザーが切り替わった場合（別アカウントへのサインイン、または
      // サインアウト）、本人専用のFutureProvider群を無効化する。これらは
      // `ref.watch`で現在ユーザーIDの変化を監視していないため、明示的な
      // invalidateなしには前のユーザーのキャッシュ済みデータ（プロフィール・
      // マイログ・フォロー関係など）が次のユーザーの画面にそのまま表示され
      // 続けてしまう（実機で確認済みの不具合）。
      if (previous?.id != next?.id) {
        ref.invalidate(myProfileProvider);
        ref.invalidate(myProfileViewCountProvider);
        ref.invalidate(myReviewViewCountProvider);
        ref.invalidate(myLogsProvider);
        ref.invalidate(myCollectionsProvider);
        ref.invalidate(myFavoritesProvider);
        ref.invalidate(followingListProvider);
        ref.invalidate(followersListProvider);
        ref.invalidate(blockedUsersListProvider);
        ref.invalidate(followingFeedProvider);
        ref.invalidate(isFollowingProvider);
        ref.invalidate(isFollowedByProvider);
        ref.invalidate(isBlockedProvider);
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
