/// 生年月（年・月のみ、日は不明）から、確実に18歳以上と判定できるかどうかを返す。
/// [birthYear]・[birthMonth] のどちらかが未設定ならfalse（成人と確定できない）を返す。
///
/// 生まれた月の途中で18歳になる（日は不明）ため、誕生月と同じ月の間は「まだ17歳の
/// 可能性がある」として非成人扱いにし、翌月になって初めて成人と判定する
/// （年齢確認としては安全側に倒す）。
bool isAdultBirthYearMonth(int? birthYear, int? birthMonth) {
  if (birthYear == null || birthMonth == null) return false;
  final now = DateTime.now();
  final yearsSinceBirth = now.year - birthYear;
  if (yearsSinceBirth > 18) return true;
  if (yearsSinceBirth == 18) return now.month > birthMonth;
  return false;
}
