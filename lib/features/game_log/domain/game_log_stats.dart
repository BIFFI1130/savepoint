/// ゲームごとの「遊んだ／遊びたい」件数（全ユーザー集計、匿名化済み）。
/// game_log_stats ビュー（個々のレビュー内容やuser_idは含まない）から取得する。
class GameLogStats {
  const GameLogStats({
    required this.gameId,
    required this.name,
    this.coverUrl,
    required this.playedCount,
    required this.wantToPlayCount,
  });

  final int gameId;
  final String name;
  final String? coverUrl;
  final int playedCount;
  final int wantToPlayCount;

  factory GameLogStats.fromJson(Map<String, dynamic> json) {
    return GameLogStats(
      gameId: json['game_id'] as int,
      name: json['name'] as String? ?? '(タイトル不明)',
      coverUrl: json['cover_url'] as String?,
      playedCount: json['played_count'] as int? ?? 0,
      wantToPlayCount: json['want_to_play_count'] as int? ?? 0,
    );
  }
}
