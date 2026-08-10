import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../game_log/domain/game_log_stats.dart';
import '../../../game_log/presentation/providers/log_providers.dart';

/// 「みんなが遊びたい」ランキング（want_to_play件数が多い順）。
final trendingWantToPlayProvider =
    FutureProvider.family<List<GameLogStats>, bool>((ref, includeAdult) async {
  return ref
      .read(statsRepositoryProvider)
      .fetchTopWantToPlay(includeAdult: includeAdult);
});

/// 「みんなが遊んだ」ランキング（played件数が多い順）。
final trendingPlayedProvider =
    FutureProvider.family<List<GameLogStats>, bool>((ref, includeAdult) async {
  return ref
      .read(statsRepositoryProvider)
      .fetchTopPlayed(includeAdult: includeAdult);
});
