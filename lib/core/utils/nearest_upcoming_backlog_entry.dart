import '../../features/game_log/domain/game_log.dart';
import 'release_countdown.dart';

/// 「遊びたい」記録のうち、発売日が今日以降で最も近いものを返す。
/// 該当が無ければnull。複数件が同日の場合はゲームIDの昇順で安定的に選ぶ
/// （表示が実行のたびに入れ替わらないようにするため）。
GameLogWithGame? nearestUpcomingBacklogEntry(List<GameLogWithGame> logs) {
  final candidates = logs.where((entry) {
    if (entry.log.status != GameLogStatus.wantToPlay) return false;
    return releaseCountdownLabel(entry.game.firstReleaseDate) != null;
  }).toList()
    ..sort((a, b) {
      final dateCompare = a.game.firstReleaseDate!.compareTo(
        b.game.firstReleaseDate!,
      );
      if (dateCompare != 0) return dateCompare;
      return a.game.id.compareTo(b.game.id);
    });
  return candidates.isEmpty ? null : candidates.first;
}
