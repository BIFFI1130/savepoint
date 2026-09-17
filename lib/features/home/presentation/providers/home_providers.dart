import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../game_log/domain/game_log.dart';
import '../../../game_log/presentation/providers/log_providers.dart';
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
  bool matchAllGenres,
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
      matchAllGenres: filter.matchAllGenres,
    ),
    live: () => ref.read(igdbRepositoryProvider).weeklyReleases(
          platforms: filter.platforms,
          genres: filter.genres,
          includeAdult: filter.includeAdult,
          includeIndie: filter.includeIndie,
          matchAllGenres: filter.matchAllGenres,
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
      matchAllGenres: filter.matchAllGenres,
    ),
    live: () => ref.read(igdbRepositoryProvider).monthlyReleases(
          platforms: filter.platforms,
          genres: filter.genres,
          includeAdult: filter.includeAdult,
          includeIndie: filter.includeIndie,
          matchAllGenres: filter.matchAllGenres,
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
      matchAllGenres: filter.matchAllGenres,
    ),
    live: () => ref.read(igdbRepositoryProvider).top100(
          platforms: filter.platforms,
          genres: filter.genres,
          includeAdult: filter.includeAdult,
          includeIndie: filter.includeIndie,
          matchAllGenres: filter.matchAllGenres,
        ),
  );
});

/// 自分が「遊んだ／遊びたい」に追加したゲームの関連作品（IGDBのsimilar_games、
/// 関連度順）を、最近追加した記録から順にたどって上限[limit]件まで集める。
/// 既に自分の記録にあるゲームは除外し、複数の記録から重複して出てきた関連作品は
/// 最初に見つかった（＝より最近追加した記録に近い）ものを優先する。
List<SimilarGame> _orderedSimilarGames(
  List<GameLogWithGame> logs, {
  required int limit,
}) {
  if (logs.isEmpty) return const [];

  final sortedLogs = [...logs]
    ..sort((a, b) => b.log.createdAt.compareTo(a.log.createdAt));
  final loggedGameIds = logs.map((e) => e.game.id).toSet();

  final seenIds = <int>{};
  final recommendations = <SimilarGame>[];
  for (final entry in sortedLogs) {
    for (final similar in entry.game.similarGames) {
      if (loggedGameIds.contains(similar.id)) continue;
      if (!seenIds.add(similar.id)) continue;
      recommendations.add(similar);
      if (recommendations.length >= limit) return recommendations;
    }
  }
  return recommendations;
}

/// ホーム画面「あなたへのおすすめ」カルーセル用（表示件数が少ないため軽量な
/// [SimilarGame]のまま、上限20件）。
final recommendedGamesProvider = FutureProvider<List<SimilarGame>>((ref) async {
  final logs = await ref.watch(myLogsProvider.future);
  return _orderedSimilarGames(logs, limit: 20);
});

/// [recommendedGamesFullProvider]が候補として集めるゲーム数の上限。
/// ジャンル・対応ハードで絞り込んでも表示件数が極端に減らないよう、実際の
/// 表示件数（[recommendedGamesDisplayLimit]）よりかなり多めに候補を集めておき、
/// 絞り込みは呼び出し側（画面）でこの大きい候補集合に対して行う。
const recommendedGamesCandidateLimit = 300;

/// 「あなたへのおすすめ」全件一覧画面の表示件数上限。絞り込み適用後、この件数まで表示する。
const recommendedGamesDisplayLimit = 60;

/// 「あなたへのおすすめ」全件一覧画面用。同じ優先順位で多め（候補として上限
/// [recommendedGamesCandidateLimit]件）に集めたうえ、ジャンル・対応ハード等で
/// 絞り込めるよう、`games`テーブルから完全な[Game]情報を取得する。実際に画面に
/// 表示するのは絞り込み後の先頭[recommendedGamesDisplayLimit]件だが、絞り込みで
/// 除外される分を見越して候補自体は多めに保持しておく（関連作品として出てくる
/// ゲーム自体は、まだ誰も詳細を開いたことがなく`games`テーブルに存在しない場合も
/// ありうるため、そのようなIDは結果から除外する）。
final recommendedGamesFullProvider = FutureProvider<List<Game>>((ref) async {
  final logs = await ref.watch(myLogsProvider.future);
  final similarGames = _orderedSimilarGames(
    logs,
    limit: recommendedGamesCandidateLimit,
  );
  if (similarGames.isEmpty) return const [];

  final ids = similarGames.map((e) => e.id).toList(growable: false);
  final games =
      await ref.read(gamesCacheRepositoryProvider).gamesByIds(ids);
  final gamesById = {for (final game in games) game.id: game};

  return [
    for (final similar in similarGames)
      if (gamesById[similar.id] != null) gamesById[similar.id]!,
  ];
});
