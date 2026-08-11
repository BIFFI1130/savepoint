import '../../game_log/domain/game_log.dart';

enum SummaryPeriodType { month, year }

/// 指定期間（月 or 年）内の記録をまとめた集計結果。
class PeriodSummary {
  const PeriodSummary({
    required this.periodStart,
    required this.periodType,
    required this.playedEntries,
    required this.wantToPlayAddedCount,
    required this.ratingCounts,
  });

  final DateTime periodStart;
  final SummaryPeriodType periodType;

  /// 期間内に「遊んだ」として記録された作品。
  final List<GameLogWithGame> playedEntries;

  /// 期間内に新規で「遊びたい」に追加された件数。
  final int wantToPlayAddedCount;

  /// 星1〜5ごとの件数（評価未入力は含まない）。
  final Map<int, int> ratingCounts;

  int get playedCount => playedEntries.length;

  double? get averageRating {
    final rated = playedEntries
        .map((e) => e.log.rating)
        .whereType<int>()
        .toList(growable: false);
    if (rated.isEmpty) return null;
    return rated.reduce((a, b) => a + b) / rated.length;
  }

  DateTime get periodEnd => periodType == SummaryPeriodType.month
      ? DateTime(periodStart.year, periodStart.month + 1)
      : DateTime(periodStart.year + 1, periodStart.month);

  String get periodLabel => periodType == SummaryPeriodType.month
      ? '${periodStart.year}年${periodStart.month}月'
      : '${periodStart.year}年';
}

/// [logs] のうち [periodStart]〜[periodType] の範囲に記録された（`createdAt` 基準）ものを集計する。
PeriodSummary summarizePeriod(
  List<GameLogWithGame> logs, {
  required DateTime periodStart,
  required SummaryPeriodType periodType,
}) {
  final periodEnd = periodType == SummaryPeriodType.month
      ? DateTime(periodStart.year, periodStart.month + 1)
      : DateTime(periodStart.year + 1, periodStart.month);

  bool inPeriod(DateTime dt) =>
      !dt.isBefore(periodStart) && dt.isBefore(periodEnd);

  final entriesInPeriod =
      logs.where((e) => inPeriod(e.log.createdAt)).toList(growable: false);
  final played = entriesInPeriod
      .where((e) => e.log.status == GameLogStatus.played)
      .toList(growable: false);
  final wantToPlayAddedCount = entriesInPeriod
      .where((e) => e.log.status == GameLogStatus.wantToPlay)
      .length;

  final ratingCounts = <int, int>{for (var i = 1; i <= 5; i++) i: 0};
  for (final entry in played) {
    final rating = entry.log.rating;
    if (rating != null) {
      ratingCounts[rating] = (ratingCounts[rating] ?? 0) + 1;
    }
  }

  return PeriodSummary(
    periodStart: periodStart,
    periodType: periodType,
    playedEntries: played,
    wantToPlayAddedCount: wantToPlayAddedCount,
    ratingCounts: ratingCounts,
  );
}
