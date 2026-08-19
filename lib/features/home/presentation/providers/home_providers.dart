import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../game_search/domain/game.dart';
import '../../../game_search/presentation/providers/game_search_providers.dart';
import '../../../game_search/presentation/providers/games_cache_providers.dart';

/// ホーム画面の各セクション共通の絞り込み条件。[platforms]・[genres] は複数選択可能
/// （選択されたうちどれか1つでも当てはまればOR条件で含める）。空なら絞り込みなし。
typedef HomeReleasesFilter = ({
  Set<String> platforms,
  Set<String> genres,
  bool includeAdult,
  bool includeIndie,
});

/// 今週発売のゲーム一覧。IGDB Data Dumpsのローカルミラーが新しければそちらから、
/// 古い/取得失敗時はigdb-proxy経由のライブ問い合わせにフォールバックする。
final weeklyReleasesProvider =
    FutureProvider.family<List<Game>, HomeReleasesFilter>((ref, filter) async {
  return fetchWithCacheFallback(
    ref,
    cached: (cache) => cache.weeklyReleases(
      platforms: filter.platforms,
      genres: filter.genres,
      includeAdult: filter.includeAdult,
      includeIndie: filter.includeIndie,
    ),
    live: () => ref.read(igdbRepositoryProvider).weeklyReleases(
          platforms: filter.platforms,
          genres: filter.genres,
          includeAdult: filter.includeAdult,
          includeIndie: filter.includeIndie,
        ),
  );
});

/// 今月発売のゲーム一覧。
final monthlyReleasesProvider =
    FutureProvider.family<List<Game>, HomeReleasesFilter>((ref, filter) async {
  return fetchWithCacheFallback(
    ref,
    cached: (cache) => cache.monthlyReleases(
      platforms: filter.platforms,
      genres: filter.genres,
      includeAdult: filter.includeAdult,
      includeIndie: filter.includeIndie,
    ),
    live: () => ref.read(igdbRepositoryProvider).monthlyReleases(
          platforms: filter.platforms,
          genres: filter.genres,
          includeAdult: filter.includeAdult,
          includeIndie: filter.includeIndie,
        ),
  );
});

/// IGDB公式のTop 100と同じ考え方の加重評価順トップ100。
final top100Provider =
    FutureProvider.family<List<Game>, HomeReleasesFilter>((ref, filter) async {
  return fetchWithCacheFallback(
    ref,
    cached: (cache) => cache.top100(
      platforms: filter.platforms,
      genres: filter.genres,
      includeAdult: filter.includeAdult,
      includeIndie: filter.includeIndie,
    ),
    live: () => ref.read(igdbRepositoryProvider).top100(
          platforms: filter.platforms,
          genres: filter.genres,
          includeAdult: filter.includeAdult,
          includeIndie: filter.includeIndie,
        ),
  );
});
