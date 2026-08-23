import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// ユーザーIDまたは表示名でユーザーを検索する（自分自身は除外）。
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

  /// プロフィール確認ページ（人アイコン）の「保存する」ボタンで一括保存する項目。
  /// ユーザーID（username）と表示名は別の専用エンドポイント（[setUsername]・
  /// [updateDisplayName]）で個別に保存するため、ここには含めない。
  Future<void> updateMyProfile({
    required bool isPublic,
    required String? gameHistory,
    required List<String> favoriteGenres,
  }) async {
    await supabase.from('profiles').update({
      'is_public': isPublic,
      'game_history':
          (gameHistory == null || gameHistory.isEmpty) ? null : gameHistory,
      'favorite_genres': favoriteGenres,
    }).eq('id', _myId);
  }

  /// 表示名だけを更新する（プロフィール確認ページの鉛筆アイコンから呼ばれる）。
  Future<void> updateDisplayName(String? displayName) async {
    await supabase.from('profiles').update({
      'display_name':
          (displayName == null || displayName.isEmpty) ? null : displayName,
    }).eq('id', _myId);
  }

  /// ユーザーID（半角英数字、一意）を設定する。ユーザーID入力画面（オンボーディング）
  /// からのみ呼ばれる想定。一度設定したユーザーIDは通常はプロフィール確認ページからは
  /// 変更できない（UI側で編集不可にしている）。
  Future<void> setUsername(String username) async {
    await supabase.from('profiles').update({'username': username}).eq('id', _myId);
  }

  /// 生年月（年齢確認用、日は取得しない）を設定する。生年月入力画面（オンボーディング）
  /// からのみ呼ばれる想定。
  Future<void> setBirthYearMonth({required int year, required int month}) async {
    await supabase.from('profiles').update({
      'birth_year': year,
      'birth_month': month,
    }).eq('id', _myId);
  }

  /// プロフィール画像を"avatars"バケットにアップロードし、公開URLをprofiles.avatar_urlに
  /// 保存する。アップロード先は本人のuidをフォルダ名にする（RLSポリシーがこれを前提に
  /// 本人のみ書き込み可としているため）。
  Future<String> uploadAvatar(List<int> bytes, {required String fileExt}) async {
    final path = '$_myId/avatar.$fileExt';
    await supabase.storage.from('avatars').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(upsert: true),
        );
    final url =
        '${supabase.storage.from('avatars').getPublicUrl(path)}?t=${DateTime.now().millisecondsSinceEpoch}';
    await supabase.from('profiles').update({'avatar_url': url}).eq('id', _myId);
    return url;
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

  /// フォロー中の全ユーザーの「遊んだ／遊びたい」追加を、追加日時（created_at）の
  /// 新しい順に返す。ホームの「タイムライン」タブで自分の記録と合わせて表示する。
  Future<List<FollowFeedEntry>> fetchFollowingFeed() async {
    final rows = await supabase
        .from('follow_feed')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FollowFeedEntry.fromJson)
        .toList(growable: false);
  }

  /// 特定ゲームの公開レビュー一覧（フォロー関係を問わず、公開設定の全ユーザーが対象）。
  /// サブスク特典「みんなのレビュー」用。
  Future<List<FollowFeedEntry>> fetchPublicReviewsForGame(int gameId) async {
    final rows = await supabase
        .from('game_public_reviews')
        .select()
        .eq('game_id', gameId)
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
