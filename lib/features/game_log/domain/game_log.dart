import '../../game_search/domain/game.dart';

/// 「遊んだ」か「遊びたい」かのステータス。
enum GameLogStatus {
  played,
  wantToPlay;

  static GameLogStatus fromDb(String value) {
    return value == 'want_to_play' ? GameLogStatus.wantToPlay : GameLogStatus.played;
  }

  String toDb() => this == GameLogStatus.wantToPlay ? 'want_to_play' : 'played';
}

/// ユーザーが投稿した「記録」（ステータス・評価・レビュー）。
///
/// [status] が [GameLogStatus.wantToPlay] の場合、[rating] は null になりうる
/// （未プレイのため評価がまだ無い）。
class GameLog {
  const GameLog({
    required this.id,
    required this.gameId,
    required this.status,
    this.rating,
    this.reviewText,
    this.hasSpoiler = false,
    this.isCleared = false,
    this.clearTimeMinutes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final int gameId;
  final GameLogStatus status;
  final int? rating;
  final String? reviewText;
  final bool hasSpoiler;
  final bool isCleared;
  final int? clearTimeMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory GameLog.fromJson(Map<String, dynamic> json) {
    return GameLog(
      id: json['id'] as String,
      gameId: json['game_id'] as int,
      status: GameLogStatus.fromDb(json['status'] as String? ?? 'played'),
      rating: json['rating'] as int?,
      reviewText: json['review_text'] as String?,
      hasSpoiler: json['has_spoiler'] as bool? ?? false,
      isCleared: json['is_cleared'] as bool? ?? false,
      clearTimeMinutes: json['clear_time_minutes'] as int?,
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
