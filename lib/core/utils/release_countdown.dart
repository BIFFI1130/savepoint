/// [releaseDate] が今日以降（未発売、または本日発売）の場合、
/// 「発売まであと○日」「本日発売」のラベルを返す。発売済み・日付不明の場合はnull。
String? releaseCountdownLabel(DateTime? releaseDate) {
  if (releaseDate == null) return null;
  final today = DateTime.now();
  final daysUntilRelease = DateTime(
    releaseDate.year,
    releaseDate.month,
    releaseDate.day,
  ).difference(DateTime(today.year, today.month, today.day)).inDays;
  if (daysUntilRelease == 0) return '本日発売';
  if (daysUntilRelease > 0) return '発売まであと$daysUntilRelease日';
  return null;
}
