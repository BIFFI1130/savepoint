/// ユーザー通報の理由。
enum ReportReason {
  spam('spam', 'スパム・宣伝'),
  harassment('harassment', '嫌がらせ・誹謗中傷'),
  inappropriateContent('inappropriate_content', '不適切な内容'),
  other('other', 'その他');

  const ReportReason(this.dbValue, this.label);
  final String dbValue;
  final String label;
}
