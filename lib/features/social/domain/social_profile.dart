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
    this.birthYear,
    this.birthMonth,
    this.notifyFollowingReviews = true,
    this.notifyNewFollower = true,
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
  /// 生年（年齢確認用、日は取得しない）。
  final int? birthYear;
  /// 生月（1〜12、年齢確認用）。
  final int? birthMonth;
  /// フォロー中ユーザーの新着レビュー通知を受け取るかどうか。自分のプロフィール
  /// （profilesテーブル直取得）でのみ意味を持つ。他ユーザー（profiles_publicビュー）
  /// はこの列を持たないため常にデフォルト値になる。
  final bool notifyFollowingReviews;
  /// 新しいフォロワー通知を受け取るかどうか。[notifyFollowingReviews]と同様、
  /// 自分のプロフィールでのみ意味を持つ。
  final bool notifyNewFollower;

  /// 表示名があればそれを、なければ@ユーザーID、どちらもなければ「名前未設定」を返す。
  /// 自分自身の表示にのみ使う（他ユーザーの一覧・検索結果では[publicDisplayLabel]を使う）。
  String get displayLabel {
    if (displayName != null && displayName!.isNotEmpty) return displayName!;
    if (username != null && username!.isNotEmpty) return '@$username';
    return '名前未設定';
  }

  /// 他ユーザー向けの表示用ラベル。ユーザーID（username）は表示しないため、
  /// 表示名が未設定の場合は「名前未設定」を返す。
  String get publicDisplayLabel {
    if (displayName != null && displayName!.isNotEmpty) return displayName!;
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
      birthYear: json['birth_year'] as int?,
      birthMonth: json['birth_month'] as int?,
      notifyFollowingReviews:
          json['notify_following_reviews'] as bool? ?? true,
      notifyNewFollower: json['notify_new_follower'] as bool? ?? true,
    );
  }
}
