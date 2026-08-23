import '../../game_log/domain/game_log.dart';

/// フォロー中ユーザーの「遊んだ／遊びたい」ステータス1件分。
///
/// 評価（星）・レビュー本文・ネタバレフラグ・クリア情報は、follow_feedビューが
/// 元のgame_logs.visibility（非公開/相互フォロー/全公開）に基づいて既にフィルタ
/// 済みの行のみを返す。つまりこのエントリが取得できている時点で、閲覧者は
/// レビュー内容を見る権限を持っている。
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
    this.rating,
    this.reviewText,
    this.hasSpoiler = false,
    this.isCleared = false,
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
  final double? rating;
  final String? reviewText;
  final bool hasSpoiler;
  final bool isCleared;

  /// 他ユーザーの表示用ラベル。ユーザーID（username）は表示しないため、
  /// 表示名が未設定の場合は「名前未設定」を返す。
  String get userLabel {
    if (displayName != null && displayName!.isNotEmpty) return displayName!;
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
      rating: (json['rating'] as num?)?.toDouble(),
      reviewText: json['review_text'] as String?,
      hasSpoiler: json['has_spoiler'] as bool? ?? false,
      isCleared: json['is_cleared'] as bool? ?? false,
    );
  }
}
