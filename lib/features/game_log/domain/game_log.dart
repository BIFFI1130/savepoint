import '../../game_search/domain/game.dart';

/// ユーザーが投稿した「記録」（評価＋レビュー）。
class GameLog {
  const GameLog({
    required this.id,
    required this.gameId,
    required this.rating,
    this.reviewText,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final int gameId;
  final int rating;
  final String? reviewText;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory GameLog.fromJson(Map<String, dynamic> json) {
    return GameLog(
      id: json['id'] as String,
      gameId: json['game_id'] as int,
      rating: json['rating'] as int,
      reviewText: json['review_text'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// マイログ一覧表示用に、記録と紐づくゲーム情報をまとめたもの。
class GameLogWithGame {
  const GameLogWithGame({required this.log, required this.game});

  final GameLog log;
  final Game game;

  factory GameLogWithGame.fromJson(Map<String, dynamic> json) {
    return GameLogWithGame(
      log: GameLog.fromJson(json),
      game: Game.fromJson(json['games'] as Map<String, dynamic>),
    );
  }
}
