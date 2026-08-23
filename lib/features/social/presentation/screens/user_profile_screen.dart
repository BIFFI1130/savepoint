import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/avatar_image.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../../core/widgets/igdb_footer.dart';
import '../../../../core/widgets/marquee_text.dart';
import '../../../../core/widgets/star_rating.dart';
import '../../../favorites/presentation/providers/favorite_providers.dart';
import '../../../favorites/presentation/widgets/favorite_games_list.dart';
import '../../../game_log/domain/game_log.dart';
import '../../domain/follow_feed_entry.dart';
import '../../domain/report_reason.dart';
import '../providers/social_providers.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  bool _isGridView = false;

  String get userId => widget.userId;

  Future<void> _toggleFollow(
    BuildContext context,
    WidgetRef ref,
    bool currentlyFollowing,
  ) async {
    final repo = ref.read(socialRepositoryProvider);
    try {
      if (currentlyFollowing) {
        await repo.unfollow(userId);
      } else {
        await repo.follow(userId);
        await ref.read(appAnalyticsProvider).logFollowUser();
      }
      ref.invalidate(isFollowingProvider(userId));
      ref.invalidate(userFeedProvider(userId));
      ref.invalidate(followingListProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作に失敗しました: $e')));
      }
    }
  }

  Future<void> _block(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('このユーザーをブロックしますか？'),
        content: const Text('ブロックすると、お互いにフォローできなくなり、既存のフォロー関係も解除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ブロックする'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(socialRepositoryProvider).blockUser(userId);
    ref.invalidate(isBlockedProvider(userId));
    ref.invalidate(isFollowingProvider(userId));
    ref.invalidate(followingListProvider);
    ref.invalidate(followersListProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ブロックしました')));
    }
  }

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    var selectedReason = ReportReason.spam;
    final detailController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('ユーザーを通報'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final reason in ReportReason.values)
                  ListTile(
                    onTap: () => setState(() => selectedReason = reason),
                    leading: Icon(
                      reason == selectedReason
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    title: Text(reason.label),
                    contentPadding: EdgeInsets.zero,
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: detailController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '詳細（任意）',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('通報する'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(socialRepositoryProvider)
        .reportUser(
          reportedUserId: userId,
          reason: selectedReason,
          detail: detailController.text.trim(),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('通報を受け付けました')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider(userId));
    final isFollowing =
        ref.watch(isFollowingProvider(userId)).valueOrNull ?? false;
    final isBlocked = ref.watch(isBlockedProvider(userId)).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _isGridView = !_isGridView),
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            tooltip: _isGridView ? 'リスト表示に切り替え' : 'グリッド表示に切り替え',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'block') _block(context, ref);
              if (value == 'report') _report(context, ref);
            },
            itemBuilder: (context) => [
              if (!isBlocked)
                const PopupMenuItem(value: 'block', child: Text('ブロックする')),
              const PopupMenuItem(value: 'report', child: Text('通報する')),
            ],
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const ErrorView(message: 'ユーザーが見つかりませんでした');
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Column(
                    children: [
                      AvatarImage(url: profile.avatarUrl, radius: 40),
                      const SizedBox(height: 8),
                      Text(
                        profile.displayLabel,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (profile.username != null)
                        Text(
                          '@${profile.username}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      const SizedBox(height: 16),
                      if (isBlocked)
                        OutlinedButton(
                          onPressed: () async {
                            await ref
                                .read(socialRepositoryProvider)
                                .unblockUser(userId);
                            ref.invalidate(isBlockedProvider(userId));
                          },
                          child: const Text('ブロックを解除する'),
                        )
                      else
                        FilledButton.icon(
                          onPressed: () =>
                              _toggleFollow(context, ref, isFollowing),
                          icon: Icon(
                            isFollowing ? Icons.check : Icons.person_add,
                          ),
                          label: Text(isFollowing ? 'フォロー中' : 'フォローする'),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: isBlocked
                    ? const EmptyView(
                        message: 'このユーザーをブロックしています',
                        icon: Icons.block,
                      )
                    : !isFollowing
                    ? const EmptyView(
                        message: 'フォローするとこのユーザーの「遊んだ／遊びたい」記録が見られます',
                        icon: Icons.lock_outline,
                      )
                    : !profile.isPublic
                    ? const EmptyView(
                        message: 'このユーザーは非公開設定のため、記録は表示されません',
                        icon: Icons.lock_outline,
                      )
                    : _UserFeedTabs(userId: userId, isGridView: _isGridView),
              ),
              const IgdbFooter(),
            ],
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: 'プロフィールの取得に失敗しました',
          onRetry: () => ref.invalidate(userProfileProvider(userId)),
        ),
      ),
    );
  }
}

/// フォロー中かつ公開プロフィールの相手の「遊んだ／遊びたい」を
/// タブ+リスト（またはグリッド）で表示する。
class _UserFeedTabs extends ConsumerWidget {
  const _UserFeedTabs({required this.userId, required this.isGridView});

  final String userId;
  final bool isGridView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(userFeedProvider(userId));
    return feedAsync.when(
      data: (entries) {
        final played = entries
            .where((e) => e.status == GameLogStatus.played)
            .toList();
        final wantToPlay = entries
            .where((e) => e.status == GameLogStatus.wantToPlay)
            .toList();
        return DefaultTabController(
          length: 3,
          child: Column(
            children: [
              TabBar(
                tabs: [
                  Tab(text: '遊んだ（${played.length}）'),
                  Tab(text: '遊びたい（${wantToPlay.length}）'),
                  const Tab(text: 'オレの推しゲー'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _UserGameList(entries: played, isGridView: isGridView),
                    _UserGameList(entries: wantToPlay, isGridView: isGridView),
                    _UserFavoritesTab(userId: userId, isGridView: isGridView),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        message: '記録の取得に失敗しました',
        onRetry: () => ref.invalidate(userFeedProvider(userId)),
      ),
    );
  }
}

/// フォロー中ユーザーの「オレの推しゲー」一覧。
class _UserFavoritesTab extends ConsumerWidget {
  const _UserFavoritesTab({required this.userId, required this.isGridView});

  final String userId;
  final bool isGridView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesForUserProvider(userId));
    return favoritesAsync.when(
      data: (favorites) {
        if (favorites.isEmpty) {
          return const EmptyView(
            message: 'まだ推しゲーが登録されていません',
            icon: Icons.favorite_border,
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FavoriteGamesList(favorites: favorites, isGridView: isGridView),
          ],
        );
      },
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        message: '推しゲーの取得に失敗しました',
        onRetry: () => ref.invalidate(favoritesForUserProvider(userId)),
      ),
    );
  }
}

class _UserGameList extends StatelessWidget {
  const _UserGameList({required this.entries, required this.isGridView});

  final List<FollowFeedEntry> entries;
  final bool isGridView;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const EmptyView(
        message: 'まだ記録がありません',
        icon: Icons.videogame_asset_outlined,
      );
    }
    if (isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.7,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return GestureDetector(
            onTap: () => context.push('/games/${entry.gameId}'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CoverImage(
                url: entry.gameCoverUrl,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          );
        },
      );
    }
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final hasReviewText =
            entry.reviewText != null && entry.reviewText!.isNotEmpty;
        return ListTile(
          leading: CoverImage(url: entry.gameCoverUrl, width: 44, height: 60),
          title: MarqueeText(
            key: ValueKey(entry.gameId),
            text: entry.displayGameName,
          ),
          subtitle: entry.rating != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StarRating(rating: entry.rating!.toDouble(), size: 16),
                          if (entry.hasSpoiler) ...[
                            const SizedBox(width: 6),
                            const Chip(
                              label: Text('ネタバレあり'),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ],
                      ),
                      if (hasReviewText)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            entry.reviewText!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                )
              : null,
          isThreeLine: hasReviewText,
          onTap: () => context.push('/games/${entry.gameId}'),
        );
      },
    );
  }
}
