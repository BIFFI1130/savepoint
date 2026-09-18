import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../game_log/domain/game_log_stats.dart';
import '../../../game_log/presentation/providers/log_providers.dart';
import '../../../game_search/domain/game.dart';
import '../../../game_search/presentation/providers/game_search_providers.dart';

/// トレンド画面の絞り込み条件。[genres] は複数選択可能で、[matchAllGenres] が
/// falseなら選択されたうちどれか1つでも当てはまればOR条件、trueなら全てに
/// 当てはまるものだけAND条件で含める。
typedef TrendingFilter = ({
  bool includeAdult,
  Set<String> genres,
  bool matchAllGenres,
});

/// 「みんなが遊びたい」ランキング（want_to_play件数が多い順）。
final trendingWantToPlayProvider =
    FutureProvider.family<List<GameLogStats>, TrendingFilter>((ref, filter) async {
  return ref.read(statsRepositoryProvider).fetchTopWantToPlay(
        includeAdult: filter.includeAdult,
        genres: filter.genres,
        matchAllGenres: filter.matchAllGenres,
      );
});

/// 「みんなが遊んだ」ランキング（played件数が多い順）。
final trendingPlayedProvider =
    FutureProvider.family<List<GameLogStats>, TrendingFilter>((ref, filter) async {
  return ref.read(statsRepositoryProvider).fetchTopPlayed(
        includeAdult: filter.includeAdult,
        genres: filter.genres,
        matchAllGenres: filter.matchAllGenres,
      );
});

/// 「IGDBトレンド」ランキング（IGDB自体で現在プレイ中登録数が多い順、試験実装）。
/// 他の2つと違いSavePoint内の記録ではなくIGDB側の世界規模のデータで、
/// キャッシュ経由のフォールバックも無い（常にライブ問い合わせ）。
final igdbPopularityTrendProvider =
    FutureProvider.family<List<Game>, TrendingFilter>((ref, filter) async {
  return ref.read(igdbRepositoryProvider).popularityTrend(
        includeAdult: filter.includeAdult,
        genres: filter.genres,
        matchAllGenres: filter.matchAllGenres,
      );
});
