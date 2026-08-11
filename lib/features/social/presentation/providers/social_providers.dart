import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/social_repository.dart';
import '../../domain/follow_feed_entry.dart';
import '../../domain/social_profile.dart';

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SocialRepository();
});

/// 自分のプロフィール（ユーザー名・表示名・公開設定）。
final myProfileProvider = FutureProvider<SocialProfile?>((ref) async {
  return ref.read(socialRepositoryProvider).fetchMyProfile();
});

/// フォロー中ユーザーの活動フィード（ステータスのみ）。
final followFeedProvider = FutureProvider<List<FollowFeedEntry>>((ref) async {
  return ref.read(socialRepositoryProvider).fetchFollowFeed();
});

/// 指定ユーザーのプロフィール。
final userProfileProvider =
    FutureProvider.family<SocialProfile?, String>((ref, userId) async {
  return ref.read(socialRepositoryProvider).fetchProfile(userId);
});

/// 自分が指定ユーザーをフォロー中かどうか。
final isFollowingProvider =
    FutureProvider.family<bool, String>((ref, userId) async {
  return ref.read(socialRepositoryProvider).isFollowing(userId);
});

/// 自分が指定ユーザーをブロック中かどうか。
final isBlockedProvider =
    FutureProvider.family<bool, String>((ref, userId) async {
  return ref.read(socialRepositoryProvider).isBlocked(userId);
});

/// 指定ユーザーのステータス一覧（フォロー中かつ公開プロフィールの場合のみ中身が返る）。
final userFeedProvider =
    FutureProvider.family<List<FollowFeedEntry>, String>((ref, userId) async {
  return ref.read(socialRepositoryProvider).fetchFollowFeedForUser(userId);
});

final followingListProvider = FutureProvider<List<SocialProfile>>((ref) async {
  return ref.read(socialRepositoryProvider).fetchFollowing();
});

final followersListProvider = FutureProvider<List<SocialProfile>>((ref) async {
  return ref.read(socialRepositoryProvider).fetchFollowers();
});

final blockedUsersListProvider =
    FutureProvider<List<SocialProfile>>((ref) async {
  return ref.read(socialRepositoryProvider).fetchBlockedUsers();
});
