import '../domain/game_log.dart';

/// CSVの1フィールドをエスケープする。カンマ・ダブルクォート・改行を含む場合のみ
/// ダブルクォートで囲み、内部のダブルクォートは二重化する（RFC 4180準拠）。
String _csvField(Object? value) {
  final text = value?.toString() ?? '';
  if (text.contains(',') || text.contains('"') || text.contains('\n')) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// マイログ一覧をCSV（Excel等で開ける形式）に変換する。エクスポート・共有機能用。
/// 先頭にUTF-8 BOMを付け、Excelで文字化けせず開けるようにしている。
String buildLogsCsv(List<GameLogWithGame> logs) {
  final buffer = StringBuffer('﻿');
  buffer.writeln(
    [
      'タイトル',
      'ステータス',
      '評価',
      'レビュー',
      'クリア済み',
      '優先度',
      '公開範囲',
      '追加日',
      '更新日',
    ].map(_csvField).join(','),
  );

  for (final entry in logs) {
    final log = entry.log;
    buffer.writeln(
      [
        entry.game.displayName,
        log.status == GameLogStatus.played ? '遊んだ' : '遊びたい',
        log.rating?.toString() ?? '',
        log.reviewText ?? '',
        log.isCleared ? 'はい' : 'いいえ',
        log.priority?.label ?? '',
        log.visibility.label,
        _formatDate(log.createdAt),
        _formatDate(log.updatedAt),
      ].map(_csvField).join(','),
    );
  }

  return buffer.toString();
}
