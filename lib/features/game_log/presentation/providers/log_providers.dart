import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/log_repository.dart';
import '../../domain/game_log.dart';

final logRepositoryProvider = Provider<LogRepository>((ref) {
  return LogRepository();
});

/// 自分のマイログ一覧。記録の追加・編集後は `ref.invalidate(myLogsProvider)` で再取得する。
final myLogsProvider = FutureProvider<List<GameLogWithGame>>((ref) async {
  return ref.read(logRepositoryProvider).fetchMyLogs();
});

/// 指定ゲームに対する自分の既存の記録（あれば編集フォームの初期値に使う）。
final existingLogProvider =
    FutureProvider.family<GameLog?, int>((ref, gameId) async {
  return ref.read(logRepositoryProvider).fetchLogForGame(gameId);
});
