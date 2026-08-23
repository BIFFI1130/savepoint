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
    this.avgRating,
    this.ratingCount = 0,
    this.genres = const [],
    this.favoriteCount = 0,
  });

  final int gameId;
  final String name;
  final String? coverUrl;
  final int playedCount;
  final int wantToPlayCount;
  final String? nameJa;

  /// 全ユーザーの評価平均（「遊んだ」かつ評価入力済みのログのみが対象）。
  final double? avgRating;

  /// 評価件数（[avgRating] の算出対象になった件数）。
  final int ratingCount;

  /// 成人向け作品かどうか（IGDBのthemesに"Erotic"が含まれるかで判定）。
  final bool isAdult;

  /// 開発元が日本の会社かどうか。タイトルを日本語表示するかどうかの判定に使う。
  final bool isJapaneseDeveloper;

  /// IGDBのジャンル名（英語）一覧。ジャンルフィルタの絞り込みに使う。
  final List<String> genres;

  /// 「オレの推しゲー」に登録しているユーザー数（全ユーザー集計）。
  final int favoriteCount;

  /// 表示用のタイトル。IGDBのLocalized Title（日本）があればそれを、無ければ原題を返す。
  String get displayName => nameJa ?? name;

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
      avgRating: (json['avg_rating'] as num?)?.toDouble(),
      ratingCount: json['rating_count'] as int? ?? 0,
      genres: (json['genres'] as List?)?.cast<String>() ?? const [],
      favoriteCount: json['favorite_count'] as int? ?? 0,
    );
  }
}
