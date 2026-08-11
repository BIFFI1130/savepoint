import '../../game_search/domain/game.dart';

/// コレクション一覧表示用（collection_summary ビューから取得）。
class Collection {
  const Collection({
    required this.id,
    required this.name,
    required this.gameCount,
    this.coverUrls = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final int gameCount;

  /// 直近追加された最大4件分のカバー画像URL（一覧のコラージュ表示用）。
  final List<String?> coverUrls;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id'] as String,
      name: json['name'] as String,
      gameCount: json['game_count'] as int? ?? 0,
      coverUrls: (json['cover_urls'] as List?)?.cast<String?>() ?? const [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// コレクションに含まれる1作品（collection_games + games のjoin結果）。
class CollectionGame {
  const CollectionGame({required this.game, required this.addedAt});

  final Game game;
  final DateTime addedAt;

  factory CollectionGame.fromJson(Map<String, dynamic> json) {
    return CollectionGame(
      game: Game.fromJson(json['games'] as Map<String, dynamic>),
      addedAt: DateTime.parse(json['added_at'] as String),
    );
  }
}
