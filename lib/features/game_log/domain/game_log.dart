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

/// 記録（レビュー）ごとの公開範囲。「共有するかどうか」だけを持ち、「誰に共有するか」は
/// プロフィール側の設定（[ProfileVisibility]）で決まる。最終的な可視性は、記録が
/// 「全公開」かつ、プロフィールの設定で許可された相手、で決まる。
enum GameLogVisibility {
  private_('private', '非公開', '自分にのみ表示されます'),
  public(
    'public',
    '全公開',
    'プロフィールの公開設定に応じて、フォロー中のユーザーや「みんなのレビュー」'
        'に表示されます',
  );

  const GameLogVisibility(this.dbValue, this.label, this.description);
  final String dbValue;
  final String label;
  final String description;

  static GameLogVisibility fromDb(String? value) {
    return value == 'private'
        ? GameLogVisibility.private_
        : GameLogVisibility.public;
  }
}

/// 「遊びたい」リストの優先度。DB上はsmallint（1=高, 2=中, 3=低）、未設定はnull。
enum BacklogPriority {
  high(1, '高'),
  medium(2, '中'),
  low(3, '低');

  const BacklogPriority(this.dbValue, this.label);
  final int dbValue;
  final String label;

  static BacklogPriority? fromDb(int? value) {
    return switch (value) {
      1 => BacklogPriority.high,
      2 => BacklogPriority.medium,
      3 => BacklogPriority.low,
      _ => null,
    };
  }
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
    this.priority,
    this.visibility = GameLogVisibility.public,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final int gameId;
  final GameLogStatus status;
  final double? rating;
  final String? reviewText;
  final bool hasSpoiler;
  final bool isCleared;
  final BacklogPriority? priority;
  final GameLogVisibility visibility;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory GameLog.fromJson(Map<String, dynamic> json) {
    return GameLog(
      id: json['id'] as String,
      gameId: json['game_id'] as int,
      status: GameLogStatus.fromDb(json['status'] as String? ?? 'played'),
      rating: (json['rating'] as num?)?.toDouble(),
      reviewText: json['review_text'] as String?,
      hasSpoiler: json['has_spoiler'] as bool? ?? false,
      isCleared: json['is_cleared'] as bool? ?? false,
      priority: BacklogPriority.fromDb(json['priority'] as int?),
      visibility: GameLogVisibility.fromDb(json['visibility'] as String?),
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
