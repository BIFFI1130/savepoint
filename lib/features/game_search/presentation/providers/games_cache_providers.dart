import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/games_cache_repository.dart';
import '../../domain/game.dart';

/// ダンプ取り込みが古すぎる/一度も成功していない場合にライブ経路へフォールバック
/// する際の許容期限。取り込みは日次を想定しているため、余裕を持って48時間とする。
const _freshnessThreshold = Duration(hours: 48);

final gamesCacheRepositoryProvider = Provider<GamesCacheRepository>((ref) {
  return GamesCacheRepository();
});

/// ローカルミラー（IGDB Data Dumps取り込み）が「使ってよい鮮度か」。
/// 取り込みジョブが止まっていても画面が無言で空にならないよう、ここがfalseの
/// 場合は呼び出し側がライブ経路（[IgdbRepository]）にフォールバックする。
final gamesCacheFreshProvider = FutureProvider<bool>((ref) async {
  try {
    final lastSync =
        await ref.watch(gamesCacheRepositoryProvider).lastSuccessfulSync();
    if (lastSync == null) return false;
    return DateTime.now().toUtc().difference(lastSync) < _freshnessThreshold;
  } catch (error, stackTrace) {
    debugPrint('gamesCacheFreshProvider check failed: $error\n$stackTrace');
    return false;
  }
});

/// 鮮度チェック→ローカルミラー呼び出しの共通フロー。ミラーが古い場合、または
/// ミラー側の呼び出し自体が失敗した場合は、[live]（igdb-proxy経由のライブ問い合わせ）
/// にフォールバックする。
Future<List<Game>> fetchWithCacheFallback(
  Ref ref, {
  required Future<List<Game>> Function(GamesCacheRepository cache) cached,
  required Future<List<Game>> Function() live,
}) async {
  final isFresh = await ref.watch(gamesCacheFreshProvider.future);
  if (isFresh) {
    try {
      return await cached(ref.read(gamesCacheRepositoryProvider));
    } catch (error, stackTrace) {
      debugPrint('games cache fetch failed, falling back to live: $error\n$stackTrace');
    }
  }
  return live();
}
