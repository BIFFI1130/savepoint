import '../../features/game_log/domain/game_log.dart';
import 'release_countdown.dart';

/// 「遊びたい」記録のうち、本日発売のものを全件返す（ゲームID昇順で安定ソート）。
/// 該当が無ければ空リスト。
List<GameLogWithGame> todaysReleasingBacklogEntries(
  List<GameLogWithGame> logs,
) {
  final candidates = logs.where((entry) {
    if (entry.log.status != GameLogStatus.wantToPlay) return false;
    return releaseCountdownLabel(entry.game.firstReleaseDate) == '本日発売';
  }).toList()
    ..sort((a, b) => a.game.id.compareTo(b.game.id));
  return candidates;
}
