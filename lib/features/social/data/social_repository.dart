import '../../../core/supabase/supabase_client.dart';
import '../domain/follow_feed_entry.dart';
import '../domain/report_reason.dart';
import '../domain/social_profile.dart';

class SocialRepository {
  String get _myId => supabase.auth.currentUser!.id;

  Future<SocialProfile?> fetchMyProfile() async {
    final row =
        await supabase.from('profiles').select().eq('id', _myId).maybeSingle();
    if (row == null) return null;
    return SocialProfile.fromJson(row);
  }

  Future<SocialProfile?> fetchProfile(String userId) async {
    final row = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return SocialProfile.fromJson(row);
  }

  /// ユーザー名または表示名でユーザーを検索する（自分自身は除外）。
  Future<List<SocialProfile>> searchUsers(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final escaped = trimmed.replaceAll(',', '');
    final rows = await supabase
        .from('profiles')
        .select()
        .neq('id', _myId)
        .or('username.ilike.%$escaped%,display_name.ilike.%$escaped%')
        .limit(20);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(SocialProfile.fromJson)
        .toList(growable: false);
  }

  Future<void> updateMyProfile({
    required String? username,
    required String? displayName,
    required bool isPublic,
  }) async {
    await supabase.from('profiles').update({
      'username': (username == null || username.isEmpty) ? null : username,
      'display_name':
          (displayName == null || displayName.isEmpty) ? null : displayName,
      'is_public': isPublic,
    }).eq('id', _myId);
  }

  Future<bool> isFollowing(String userId) async {
    final row = await supabase
        .from('follows')
        .select()
        .eq('follower_id', _myId)
        .eq('followee_id', userId)
        .maybeSingle();
    return row != null;
  }

  Future<void> follow(String userId) async {
    await supabase.from('follows').insert({
      'follower_id': _myId,
      'followee_id': userId,
    });
  }

  Future<void> unfollow(String userId) async {
    await supabase
        .from('follows')
        .delete()
        .eq('follower_id', _myId)
        .eq('followee_id', userId);
  }

  Future<List<SocialProfile>> fetchFollowing() async {
    final rows = await supabase
        .from('follows')
        .select('followee_id')
        .eq('follower_id', _myId);
    final ids =
        (rows as List).map((r) => r['followee_id'] as String).toList();
    return _fetchProfilesByIds(ids);
  }

  Future<List<SocialProfile>> fetchFollowers() async {
    final rows = await supabase
        .from('follows')
        .select('follower_id')
        .eq('followee_id', _myId);
    final ids =
        (rows as List).map((r) => r['follower_id'] as String).toList();
    return _fetchProfilesByIds(ids);
  }

  Future<List<SocialProfile>> fetchBlockedUsers() async {
    final rows = await supabase
        .from('blocks')
        .select('blocked_id')
        .eq('blocker_id', _myId);
    final ids = (rows as List).map((r) => r['blocked_id'] as String).toList();
    return _fetchProfilesByIds(ids);
  }

  Future<bool> isBlocked(String userId) async {
    final row = await supabase
        .from('blocks')
        .select()
        .eq('blocker_id', _myId)
        .eq('blocked_id', userId)
        .maybeSingle();
    return row != null;
  }

  Future<void> blockUser(String userId) async {
    await supabase.from('blocks').insert({
      'blocker_id': _myId,
      'blocked_id': userId,
    });
  }

  Future<void> unblockUser(String userId) async {
    await supabase
        .from('blocks')
        .delete()
        .eq('blocker_id', _myId)
        .eq('blocked_id', userId);
  }

  Future<void> reportUser({
    required String reportedUserId,
    required ReportReason reason,
    String? detail,
  }) async {
    await supabase.from('reports').insert({
      'reporter_id': _myId,
      'reported_user_id': reportedUserId,
      'reason': reason.dbValue,
      'detail': (detail == null || detail.isEmpty) ? null : detail,
    });
  }

  /// フォロー中ユーザーの「遊んだ／遊びたい」ステータス一覧（新しい順）。
  Future<List<FollowFeedEntry>> fetchFollowFeed() async {
    final rows = await supabase
        .from('follow_feed')
        .select()
        .order('updated_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FollowFeedEntry.fromJson)
        .toList(growable: false);
  }

  /// 特定のフォロー中ユーザーのステータス一覧（プロフィール画面用）。
  Future<List<FollowFeedEntry>> fetchFollowFeedForUser(String userId) async {
    final rows = await supabase
        .from('follow_feed')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FollowFeedEntry.fromJson)
        .toList(growable: false);
  }

  Future<List<SocialProfile>> _fetchProfilesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final rows =
        await supabase.from('profiles').select().inFilter('id', ids);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(SocialProfile.fromJson)
        .toList(growable: false);
  }
}
