import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../game_search/domain/game.dart';
import '../../../game_search/presentation/providers/game_search_providers.dart';

/// 今週発売のゲーム一覧。[platform] がnullなら全ハード対象。
final weeklyReleasesProvider =
    FutureProvider.family<List<Game>, String?>((ref, platform) async {
  return ref.read(igdbRepositoryProvider).weeklyReleases(platform: platform);
});
