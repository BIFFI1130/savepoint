import '../../game_search/domain/game.dart';
import 'game_log.dart';

/// 「遊びたい」に積んだゲームを、IGDB由来のクリア時間から消化にかかる期間に換算した結果。
class BacklogEstimate {
  const BacklogEstimate({
    required this.entries,
    required this.missingCount,
    required this.totalSeconds,
  });

  /// クリア時間が分かる「遊びたい」記録を、短い順に並べたもの。
  final List<BacklogEntryEstimate> entries;

  /// 「遊びたい」だがクリア時間の情報が無く、合計に含められなかった本数。
  final int missingCount;

  final int totalSeconds;

  int get countedGames => entries.length;
  int get totalGames => entries.length + missingCount;
  double get totalHours => totalSeconds / 3600;

  /// 週[hoursPerWeek]時間遊ぶ場合の消化にかかる週数。
  double weeksToFinish(double hoursPerWeek) =>
      hoursPerWeek <= 0 ? 0 : totalHours / hoursPerWeek;

  /// 合計が長い順の上位[count]本（シェア画像の「重量級」表示用）。
  List<BacklogEntryEstimate> longest(int count) =>
      entries.reversed.take(count).toList(growable: false);
}

class BacklogEntryEstimate {
  const BacklogEntryEstimate({required this.entry, required this.seconds});

  final GameLogWithGame entry;
  final int seconds;

  double get hours => seconds / 3600;
}

/// 通常プレイ→急ぎ→完全の順で、使えるクリア時間（秒）を返す。無ければnull。
int? clearTimeSeconds(Game game) {
  for (final seconds in [
    game.timeToBeatNormallySeconds,
    game.timeToBeatHastilySeconds,
    game.timeToBeatCompletelySeconds,
  ]) {
    if (seconds != null && seconds > 0) return seconds;
  }
  return null;
}

/// [logs]のうち「遊びたい」の記録を集計する。
BacklogEstimate estimateBacklog(List<GameLogWithGame> logs) {
  final counted = <BacklogEntryEstimate>[];
  var missing = 0;
  var total = 0;
  for (final entry in logs) {
    if (entry.log.status != GameLogStatus.wantToPlay) continue;
    final seconds = clearTimeSeconds(entry.game);
    if (seconds == null) {
      missing++;
      continue;
    }
    counted.add(BacklogEntryEstimate(entry: entry, seconds: seconds));
    total += seconds;
  }
  counted.sort((a, b) => a.seconds.compareTo(b.seconds));
  return BacklogEstimate(
    entries: counted,
    missingCount: missing,
    totalSeconds: total,
  );
}

/// 週数を「約3週間」「約5か月」「約1年2か月」のような日本語表現にする。
String describeWeeks(double weeks) {
  if (weeks <= 0) return 'なし';
  if (weeks < 1) return '1週間未満';
  if (weeks < 8) return '約${weeks.round()}週間';
  final months = (weeks / 4.345).round();
  if (months < 24) {
    if (months < 12) return '約$monthsか月';
    final years = months ~/ 12;
    final rest = months % 12;
    return rest == 0 ? '約$years年' : '約$years年$restか月';
  }
  final years = weeks / 52.18;
  return '約${years.toStringAsFixed(1)}年';
}
