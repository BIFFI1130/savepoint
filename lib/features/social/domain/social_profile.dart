/// 他ユーザーのプロフィール（ユーザーID・表示名・公開設定・ゲーム歴・好きなジャンル）。
class SocialProfile {
  const SocialProfile({
    required this.id,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.isPublic = false,
    this.gameHistory,
    this.favoriteGenres = const [],
  });

  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final bool isPublic;
  /// ゲーム歴（自由記述、任意）。
  final String? gameHistory;
  /// 好きなジャンル（複数選択、genreOptionsの値と対応）。
  final List<String> favoriteGenres;

  /// 表示名があればそれを、なければ@ユーザーID、どちらもなければ「名前未設定」を返す。
  String get displayLabel {
    if (displayName != null && displayName!.isNotEmpty) return displayName!;
    if (username != null && username!.isNotEmpty) return '@$username';
    return '名前未設定';
  }

  factory SocialProfile.fromJson(Map<String, dynamic> json) {
    return SocialProfile(
      id: json['id'] as String,
      username: json['username'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isPublic: json['is_public'] as bool? ?? false,
      gameHistory: json['game_history'] as String?,
      favoriteGenres:
          (json['favorite_genres'] as List?)?.cast<String>() ?? const [],
    );
  }
}
