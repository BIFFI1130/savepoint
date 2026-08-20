import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../analytics/analytics_service.dart';
import '../../features/achievements/presentation/screens/achievements_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/collections/presentation/screens/collection_detail_screen.dart';
import '../../features/collections/presentation/screens/collections_screen.dart';
import '../../features/favorites/presentation/screens/favorite_games_edit_screen.dart';
import '../../features/calendar/presentation/screens/release_calendar_screen.dart';
import '../../features/game_log/presentation/screens/log_review_screen.dart';
import '../../features/home/presentation/providers/home_providers.dart';
import '../../features/home/presentation/screens/release_list_screen.dart';
import '../../features/social/presentation/screens/birthdate_onboarding_screen.dart';
import '../../features/social/presentation/screens/my_profile_screen.dart';
import '../../features/social/presentation/screens/social_feed_screen.dart';
import '../../features/social/presentation/screens/user_list_screen.dart';
import '../../features/social/presentation/screens/user_profile_screen.dart';
import '../../features/social/presentation/screens/user_search_screen.dart';
import '../../features/social/presentation/screens/username_onboarding_screen.dart';
import '../../features/subscription/presentation/screens/paywall_screen.dart';
import '../../features/summary/presentation/screens/summary_screen.dart';
import '../../features/timeline/presentation/screens/timeline_screen.dart';
import '../../features/update/presentation/screens/update_required_screen.dart';
import '../onboarding/birthdate_gate.dart';
import '../onboarding/username_gate.dart';
import '../supabase/supabase_client.dart';
import '../update/update_gate.dart';
import 'home_shell.dart';
import '../../features/game_search/presentation/screens/game_detail_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refreshStream = GoRouterRefreshStream(supabase.auth.onAuthStateChange);
  ref.onDispose(refreshStream.dispose);
  final usernameGate = ref.read(usernameGateProvider);
  final birthdateGate = ref.read(birthdateGateProvider);
  final updateGate = ref.read(updateGateProvider);

  return GoRouter(
    initialLocation: '/home',
    observers: [ref.read(analyticsRouteObserverProvider)],
    refreshListenable: Listenable.merge(
      [refreshStream, usernameGate, birthdateGate, updateGate],
    ),
    redirect: (context, state) {
      final isUpdateRoute = state.matchedLocation == '/update-required';

      // 古いビルドは、ログイン状態に関わらず一切使わせない（サインイン画面より優先）。
      if (updateGate.needsUpdate == true && !isUpdateRoute) {
        return '/update-required';
      }
      if (updateGate.needsUpdate == false && isUpdateRoute) {
        return '/home';
      }

      final isLoggedIn = supabase.auth.currentSession != null;
      final isAuthRoute =
          state.matchedLocation == '/sign-in' ||
          state.matchedLocation == '/sign-up' ||
          state.matchedLocation == '/forgot-password';
      final isOnboardingRoute = state.matchedLocation == '/onboarding/username';

      if (!isLoggedIn && !isAuthRoute) return '/sign-in';
      if (isLoggedIn && isAuthRoute) return '/home';

      if (isLoggedIn) {
        // ユーザーIDが未設定（テスト段階中は設定済みでも常に）の間は、
        // ユーザーID入力画面以外への遷移をすべてブロックする。
        if (usernameGate.needsOnboarding == true && !isOnboardingRoute) {
          return '/onboarding/username';
        }
        if (usernameGate.needsOnboarding == false && isOnboardingRoute) {
          return '/home';
        }

        // ユーザーIDの設定が済んでいる場合のみ、続けて生年月の入力を確認する
        // （ユーザーID入力画面の最中に横取りしないようにするため）。
        final isBirthdateRoute = state.matchedLocation == '/onboarding/birthdate';
        if (usernameGate.needsOnboarding == false) {
          if (birthdateGate.needsOnboarding == true && !isBirthdateRoute) {
            return '/onboarding/birthdate';
          }
          if (birthdateGate.needsOnboarding == false && isBirthdateRoute) {
            return '/home';
          }
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/update-required',
        builder: (context, state) => const UpdateRequiredScreen(),
      ),
      GoRoute(
        path: '/onboarding/username',
        builder: (context, state) => const UsernameOnboardingScreen(),
      ),
      GoRoute(
        path: '/onboarding/birthdate',
        builder: (context, state) => const BirthdateOnboardingScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) {
          final initialIndex = state.extra is int ? state.extra as int : 0;
          return HomeShell(initialIndex: initialIndex);
        },
      ),
      GoRoute(
        path: '/calendar',
        builder: (context, state) => const ReleaseCalendarScreen(),
      ),
      GoRoute(
        path: '/home/weekly',
        builder: (context, state) => ReleaseListScreen(
          type: ReleaseListType.weekly,
          initialFilter: state.extra is HomeReleasesFilter
              ? state.extra as HomeReleasesFilter
              : null,
        ),
      ),
      GoRoute(
        path: '/home/monthly',
        builder: (context, state) => ReleaseListScreen(
          type: ReleaseListType.monthly,
          initialFilter: state.extra is HomeReleasesFilter
              ? state.extra as HomeReleasesFilter
              : null,
        ),
      ),
      GoRoute(
        path: '/home/top100',
        builder: (context, state) => ReleaseListScreen(
          type: ReleaseListType.top100,
          initialFilter: state.extra is HomeReleasesFilter
              ? state.extra as HomeReleasesFilter
              : null,
        ),
      ),
      GoRoute(
        path: '/games/:id',
        builder: (context, state) {
          final gameId = int.parse(state.pathParameters['id']!);
          return GameDetailScreen(gameId: gameId);
        },
      ),
      GoRoute(
        path: '/games/:id/log',
        builder: (context, state) {
          final gameId = int.parse(state.pathParameters['id']!);
          return LogReviewScreen(gameId: gameId);
        },
      ),
      GoRoute(
        path: '/collections',
        builder: (context, state) => const CollectionsScreen(),
      ),
      GoRoute(
        path: '/collections/:id',
        builder: (context, state) {
          final collectionId = state.pathParameters['id']!;
          return CollectionDetailScreen(collectionId: collectionId);
        },
      ),
      GoRoute(
        path: '/summary',
        builder: (context, state) => const SummaryScreen(),
      ),
      GoRoute(
        path: '/favorites/edit',
        builder: (context, state) => const FavoriteGamesEditScreen(),
      ),
      GoRoute(
        path: '/achievements',
        builder: (context, state) => const AchievementsScreen(),
      ),
      GoRoute(
        path: '/subscription/paywall',
        builder: (context, state) => const PaywallScreen(),
      ),
      GoRoute(
        path: '/timeline',
        builder: (context, state) => const TimelineScreen(),
      ),
      GoRoute(
        path: '/social',
        builder: (context, state) => const SocialFeedScreen(),
      ),
      GoRoute(
        path: '/social/search',
        builder: (context, state) => const UserSearchScreen(),
      ),
      GoRoute(
        path: '/social/my-profile',
        builder: (context, state) => const MyProfileScreen(),
      ),
      GoRoute(
        path: '/social/followers',
        builder: (context, state) =>
            const UserListScreen(mode: UserListMode.followers),
      ),
      GoRoute(
        path: '/social/blocked',
        builder: (context, state) =>
            const UserListScreen(mode: UserListMode.blocked),
      ),
      GoRoute(
        path: '/users/:id',
        builder: (context, state) {
          final userId = state.pathParameters['id']!;
          return UserProfileScreen(userId: userId);
        },
      ),
    ],
  );
});

/// SupabaseのonAuthStateChange StreamをListenableに変換し、
/// go_routerのrefreshListenableに渡してログイン/ログアウト時にredirectを再評価させる。
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
