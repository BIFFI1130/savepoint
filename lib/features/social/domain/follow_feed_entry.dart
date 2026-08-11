import '../../game_log/domain/game_log.dart';

/// フォロー中ユーザーの「遊んだ／遊びたい」ステータス1件分。
///
/// follow_feedビュー由来のため、評価・レビュー・ネタバレ・クリア情報・優先度は
/// 一切含まれない（意図的にステータスのみを公開する設計）。
class FollowFeedEntry {
  const FollowFeedEntry({
    required this.userId,
    this.username,
    this.displayName,
    this.avatarUrl,
    required this.gameId,
    required this.gameName,
    this.gameNameJa,
    this.gameCoverUrl,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String userId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final int gameId;
  final String gameName;
  final String? gameNameJa;
  final String? gameCoverUrl;
  final GameLogStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get userLabel {
    if (displayName != null && displayName!.isNotEmpty) return displayName!;
    if (username != null && username!.isNotEmpty) return '@$username';
    return '名前未設定';
  }

  String get displayGameName =>
      (gameNameJa != null && gameNameJa!.isNotEmpty) ? gameNameJa! : gameName;

  factory FollowFeedEntry.fromJson(Map<String, dynamic> json) {
    return FollowFeedEntry(
      userId: json['user_id'] as String,
      username: json['username'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      gameId: json['game_id'] as int,
      gameName: json['game_name'] as String,
      gameNameJa: json['game_name_ja'] as String?,
      gameCoverUrl: json['game_cover_url'] as String?,
      status: GameLogStatus.fromDb(json['status'] as String? ?? 'played'),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
