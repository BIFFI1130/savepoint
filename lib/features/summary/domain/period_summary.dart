import '../../game_search/domain/genre_options.dart';
import '../../game_log/domain/game_log.dart';

enum SummaryPeriodType { month, year, all }

/// 指定期間（月・年・すべて）内の記録をまとめた集計結果。
class PeriodSummary {
  const PeriodSummary({
    required this.periodStart,
    required this.periodType,
    required this.playedEntries,
    required this.wantToPlayAddedCount,
    required this.ratingCounts,
    required this.genreCounts,
  });

  final DateTime periodStart;
  final SummaryPeriodType periodType;

  /// 期間内に「遊んだ」として記録された作品。
  final List<GameLogWithGame> playedEntries;

  /// 期間内に新規で「遊びたい」に追加された件数。
  final int wantToPlayAddedCount;

  /// 星1〜5ごとの件数（評価未入力は含まない）。
  final Map<int, int> ratingCounts;

  /// ジャンル表示ラベルごとの件数（1本のゲームが複数ジャンルに該当する場合は両方でカウント）。
  /// 件数の多い順。
  final Map<String, int> genreCounts;

  int get playedCount => playedEntries.length;

  double? get averageRating {
    final rated = playedEntries
        .map((e) => e.log.rating)
        .whereType<int>()
        .toList(growable: false);
    if (rated.isEmpty) return null;
    return rated.reduce((a, b) => a + b) / rated.length;
  }

  DateTime get periodEnd => switch (periodType) {
        SummaryPeriodType.month =>
          DateTime(periodStart.year, periodStart.month + 1),
        SummaryPeriodType.year =>
          DateTime(periodStart.year + 1, periodStart.month),
        SummaryPeriodType.all => DateTime.now(),
      };

  String get periodLabel => switch (periodType) {
        SummaryPeriodType.month => '${periodStart.year}年${periodStart.month}月',
        SummaryPeriodType.year => '${periodStart.year}年',
        SummaryPeriodType.all => 'すべての記録',
      };
}

/// [logs] のうち [periodStart]〜[periodType] の範囲に記録された（`createdAt` 基準）ものを集計する。
/// [periodType] が [SummaryPeriodType.all] の場合、[periodStart] は無視して全期間を対象にする。
PeriodSummary summarizePeriod(
  List<GameLogWithGame> logs, {
  required DateTime periodStart,
  required SummaryPeriodType periodType,
}) {
  final periodEnd = periodType == SummaryPeriodType.month
      ? DateTime(periodStart.year, periodStart.month + 1)
      : DateTime(periodStart.year + 1, periodStart.month);

  bool inPeriod(DateTime dt) =>
      periodType == SummaryPeriodType.all ||
      (!dt.isBefore(periodStart) && dt.isBefore(periodEnd));

  final entriesInPeriod =
      logs.where((e) => inPeriod(e.log.createdAt)).toList(growable: false);
  final played = entriesInPeriod
      .where((e) => e.log.status == GameLogStatus.played)
      .toList(growable: false);
  final wantToPlayAddedCount = entriesInPeriod
      .where((e) => e.log.status == GameLogStatus.wantToPlay)
      .length;

  final ratingCounts = <int, int>{for (var i = 1; i <= 5; i++) i: 0};
  final genreCountsRaw = <String, int>{};
  for (final entry in played) {
    final rating = entry.log.rating;
    if (rating != null) {
      ratingCounts[rating] = (ratingCounts[rating] ?? 0) + 1;
    }
    for (final genre in entry.game.genres) {
      final label = genreLabel(genre);
      genreCountsRaw[label] = (genreCountsRaw[label] ?? 0) + 1;
    }
  }
  final genreCounts = Map.fromEntries(
    genreCountsRaw.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)),
  );

  return PeriodSummary(
    periodStart: periodStart,
    periodType: periodType,
    playedEntries: played,
    wantToPlayAddedCount: wantToPlayAddedCount,
    ratingCounts: ratingCounts,
    genreCounts: genreCounts,
  );
}
