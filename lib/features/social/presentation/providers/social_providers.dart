import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ads/interstitial_ad_service.dart';
import '../../../../core/utils/age.dart';
import '../../data/social_repository.dart';
import '../../domain/follow_feed_entry.dart';
import '../../domain/social_profile.dart';

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SocialRepository();
});

/// プロフィール編集保存時に表示する全画面広告。編集画面が開いている間に事前読み込みし、
/// 保存完了直後に表示する。
final profileSaveAdProvider = Provider<InterstitialAdService>((ref) {
  return InterstitialAdService();
});

/// 自分のプロフィール（ユーザーID・表示名・公開設定）。
final myProfileProvider = FutureProvider<SocialProfile?>((ref) async {
  return ref.read(socialRepositoryProvider).fetchMyProfile();
});

/// 自分が生年月から確実に18歳以上と判定できるかどうか。未取得・未設定の間はfalse
/// （成人向け作品を表示する選択肢を出さない、安全側の初期値）。
final isAdultUserProvider = Provider<bool>((ref) {
  final profile = ref.watch(myProfileProvider).valueOrNull;
  return isAdultBirthYearMonth(profile?.birthYear, profile?.birthMonth);
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

/// フォロー中の全ユーザーの活動（「遊んだ／遊びたい」への追加）。ホームの
/// 「タイムライン」タブで自分の記録と合わせて表示する。
final followingFeedProvider = FutureProvider<List<FollowFeedEntry>>((ref) async {
  return ref.read(socialRepositoryProvider).fetchFollowingFeed();
});

/// 指定ゲームの公開レビュー一覧（フォロー関係を問わず、公開設定の全ユーザーが対象）。
/// サブスク特典「みんなのレビュー」用。
final gamePublicReviewsProvider =
    FutureProvider.family<List<FollowFeedEntry>, int>((ref, gameId) async {
  return ref.read(socialRepositoryProvider).fetchPublicReviewsForGame(gameId);
});

final followersListProvider = FutureProvider<List<SocialProfile>>((ref) async {
  return ref.read(socialRepositoryProvider).fetchFollowers();
});

final blockedUsersListProvider =
    FutureProvider<List<SocialProfile>>((ref) async {
  return ref.read(socialRepositoryProvider).fetchBlockedUsers();
});
