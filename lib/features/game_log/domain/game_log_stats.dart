/// ゲームごとの「遊んだ／遊びたい」件数（全ユーザー集計、匿名化済み）。
/// game_log_stats ビュー（個々のレビュー内容やuser_idは含まない）から取得する。
class GameLogStats {
  const GameLogStats({
    required this.gameId,
    required this.name,
    this.coverUrl,
    required this.playedCount,
    required this.wantToPlayCount,
    this.nameJa,
    this.isAdult = false,
    this.isJapaneseDeveloper = false,
  });

  final int gameId;
  final String name;
  final String? coverUrl;
  final int playedCount;
  final int wantToPlayCount;
  final String? nameJa;

  /// 成人向け作品かどうか（IGDBのthemesに"Erotic"が含まれるかで判定）。
  final bool isAdult;

  /// 開発元が日本の会社かどうか。タイトルを日本語表示するかどうかの判定に使う。
  final bool isJapaneseDeveloper;

  /// 表示用のタイトル。開発元が日本の会社で日本語訳があればそれを、それ以外は原題を返す。
  String get displayName => isJapaneseDeveloper ? (nameJa ?? name) : name;

  factory GameLogStats.fromJson(Map<String, dynamic> json) {
    return GameLogStats(
      gameId: json['game_id'] as int,
      name: json['name'] as String? ?? '(タイトル不明)',
      coverUrl: json['cover_url'] as String?,
      playedCount: json['played_count'] as int? ?? 0,
      wantToPlayCount: json['want_to_play_count'] as int? ?? 0,
      nameJa: json['name_ja'] as String?,
      isAdult: json['is_adult'] as bool? ?? false,
      isJapaneseDeveloper: json['is_japanese_developer'] as bool? ?? false,
    );
  }
}
