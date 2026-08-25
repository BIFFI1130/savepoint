import 'game_log.dart';

/// [date]が属する週（月曜始まり）の月曜日を返す。週の識別キーとして使う。
DateTime _weekStart(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

/// 現在の週間記録ストリーク（連続して「遊んだ」を記録した週数）を計算する。
/// 今週すでに記録があればそこから、無くても先週まで記録が続いていれば
/// （今週はまだ終わっていないため）ストリークは継続中として数える。
/// 先週・今週のどちらにも記録が無ければ0を返す。
int currentWeeklyStreak(List<GameLogWithGame> logs, {DateTime? now}) {
  final activeWeeks = logs
      .where((e) => e.log.status == GameLogStatus.played)
      .map((e) => _weekStart(e.log.createdAt))
      .toSet();
  if (activeWeeks.isEmpty) return 0;

  var cursor = _weekStart(now ?? DateTime.now());
  if (!activeWeeks.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 7));
    if (!activeWeeks.contains(cursor)) return 0;
  }

  var streak = 0;
  while (activeWeeks.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 7));
  }
  return streak;
}
