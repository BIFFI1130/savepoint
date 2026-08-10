import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../game_search/domain/game.dart';
import '../../../game_search/presentation/providers/game_search_providers.dart';

/// 今週発売のゲーム一覧の絞り込み条件。[platform] がnullなら全ハード対象。
typedef WeeklyReleasesFilter = ({String? platform, bool includeAdult});

/// 今週発売のゲーム一覧。
final weeklyReleasesProvider =
    FutureProvider.family<List<Game>, WeeklyReleasesFilter>((ref, filter) async {
  return ref.read(igdbRepositoryProvider).weeklyReleases(
        platform: filter.platform,
        includeAdult: filter.includeAdult,
      );
});
