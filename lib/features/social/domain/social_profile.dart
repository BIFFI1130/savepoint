/// 他ユーザーのプロフィール（ユーザー名・表示名・公開設定）。
class SocialProfile {
  const SocialProfile({
    required this.id,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.isPublic = false,
  });

  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final bool isPublic;

  /// 表示名があればそれを、なければ@ユーザー名、どちらもなければ「名前未設定」を返す。
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
    );
  }
}
