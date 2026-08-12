/// 「推しゲー」1件分（favorite_games_feedビュー由来）。
class FavoriteGameEntry {
  const FavoriteGameEntry({
    required this.userId,
    required this.gameId,
    required this.gameName,
    this.gameNameJa,
    this.gameCoverUrl,
    required this.position,
    required this.favoritesRanked,
    required this.createdAt,
  });

  final String userId;
  final int gameId;
  final String gameName;
  final String? gameNameJa;
  final String? gameCoverUrl;
  final int position;

  /// 順位あり（1位〜5位）で表示するか、順不同で表示するか。
  final bool favoritesRanked;
  final DateTime createdAt;

  String get displayGameName =>
      (gameNameJa != null && gameNameJa!.isNotEmpty) ? gameNameJa! : gameName;

  factory FavoriteGameEntry.fromJson(Map<String, dynamic> json) {
    return FavoriteGameEntry(
      userId: json['user_id'] as String,
      gameId: json['game_id'] as int,
      gameName: json['game_name'] as String,
      gameNameJa: json['game_name_ja'] as String?,
      gameCoverUrl: json['game_cover_url'] as String?,
      position: json['position'] as int,
      favoritesRanked: json['favorites_ranked'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
