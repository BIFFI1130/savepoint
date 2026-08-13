import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../game_log/domain/game_log_stats.dart';
import '../../../game_log/presentation/providers/log_providers.dart';

/// トレンド画面の絞り込み条件。[genres] は複数選択可能で、選択されたうちどれか
/// 1つでも当てはまればOR条件で含める。
typedef TrendingFilter = ({bool includeAdult, Set<String> genres});

/// 「みんなが遊びたい」ランキング（want_to_play件数が多い順）。
final trendingWantToPlayProvider =
    FutureProvider.family<List<GameLogStats>, TrendingFilter>((ref, filter) async {
  return ref.read(statsRepositoryProvider).fetchTopWantToPlay(
        includeAdult: filter.includeAdult,
        genres: filter.genres,
      );
});

/// 「みんなが遊んだ」ランキング（played件数が多い順）。
final trendingPlayedProvider =
    FutureProvider.family<List<GameLogStats>, TrendingFilter>((ref, filter) async {
  return ref.read(statsRepositoryProvider).fetchTopPlayed(
        includeAdult: filter.includeAdult,
        genres: filter.genres,
      );
});
