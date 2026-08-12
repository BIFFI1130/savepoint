import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/achievements/presentation/screens/achievements_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/collections/presentation/screens/collection_detail_screen.dart';
import '../../features/collections/presentation/screens/collections_screen.dart';
import '../../features/favorites/presentation/screens/favorite_games_edit_screen.dart';
import '../../features/game_log/presentation/screens/log_review_screen.dart';
import '../../features/home/presentation/providers/home_providers.dart';
import '../../features/home/presentation/screens/release_list_screen.dart';
import '../../features/social/presentation/screens/profile_settings_screen.dart';
import '../../features/social/presentation/screens/social_feed_screen.dart';
import '../../features/social/presentation/screens/user_list_screen.dart';
import '../../features/social/presentation/screens/user_profile_screen.dart';
import '../../features/social/presentation/screens/user_search_screen.dart';
import '../../features/summary/presentation/screens/summary_screen.dart';
import '../../features/timeline/presentation/screens/timeline_screen.dart';
import '../supabase/supabase_client.dart';
import 'home_shell.dart';
import '../../features/game_search/presentation/screens/game_detail_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refreshStream = GoRouterRefreshStream(supabase.auth.onAuthStateChange);
  ref.onDispose(refreshStream.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refreshStream,
    redirect: (context, state) {
      final isLoggedIn = supabase.auth.currentSession != null;
      final isAuthRoute =
          state.matchedLocation == '/sign-in' ||
          state.matchedLocation == '/sign-up';

      if (!isLoggedIn && !isAuthRoute) return '/sign-in';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) {
          final initialIndex = state.extra is int ? state.extra as int : 0;
          return HomeShell(initialIndex: initialIndex);
        },
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
        path: '/social/profile-settings',
        builder: (context, state) => const ProfileSettingsScreen(),
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
