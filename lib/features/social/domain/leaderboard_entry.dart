/// フォロー内リーダーボードの1件分（直近7日間の記録数ランキング）。
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    this.username,
    this.displayName,
    this.avatarUrl,
    required this.logCount,
  });

  final String userId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final int logCount;

  String get displayLabel {
    if (displayName != null && displayName!.isNotEmpty) return displayName!;
    if (username != null && username!.isNotEmpty) return '@$username';
    return '名前未設定';
  }

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['user_id'] as String,
      username: json['username'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      logCount: json['log_count'] as int,
    );
  }
}
