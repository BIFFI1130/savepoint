import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/avatar_image.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../game_log/domain/game_log.dart';
import '../../domain/report_reason.dart';
import '../providers/social_providers.dart';

class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key, required this.userId});

  final String userId;

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
      }
      ref.invalidate(isFollowingProvider(userId));
      ref.invalidate(userFeedProvider(userId));
      ref.invalidate(followFeedProvider);
      ref.invalidate(followingListProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作に失敗しました: $e')));
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
    ref.invalidate(followFeedProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ブロックしました')));
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
    await ref.read(socialRepositoryProvider).reportUser(
          reportedUserId: userId,
          reason: selectedReason,
          detail: detailController.text.trim(),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('通報を受け付けました')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(userId));
    final isFollowing = ref.watch(isFollowingProvider(userId)).valueOrNull ?? false;
    final isBlocked = ref.watch(isBlockedProvider(userId)).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール'),
        actions: [
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
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
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (isBlocked)
                Center(
                  child: OutlinedButton(
                    onPressed: () async {
                      await ref
                          .read(socialRepositoryProvider)
                          .unblockUser(userId);
                      ref.invalidate(isBlockedProvider(userId));
                    },
                    child: const Text('ブロックを解除する'),
                  ),
                )
              else
                Center(
                  child: FilledButton.icon(
                    onPressed: () => _toggleFollow(context, ref, isFollowing),
                    icon: Icon(isFollowing ? Icons.check : Icons.person_add),
                    label: Text(isFollowing ? 'フォロー中' : 'フォローする'),
                  ),
                ),
              const SizedBox(height: 24),
              if (isBlocked)
                const EmptyView(
                  message: 'このユーザーをブロックしています',
                  icon: Icons.block,
                )
              else if (!isFollowing)
                const EmptyView(
                  message: 'フォローするとこのユーザーの「遊んだ／遊びたい」記録が見られます',
                  icon: Icons.lock_outline,
                )
              else if (!profile.isPublic)
                const EmptyView(
                  message: 'このユーザーは非公開設定のため、記録は表示されません',
                  icon: Icons.lock_outline,
                )
              else
                _UserFeedList(userId: userId),
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

class _UserFeedList extends ConsumerWidget {
  const _UserFeedList({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(userFeedProvider(userId));
    return feedAsync.when(
      data: (entries) {
        if (entries.isEmpty) {
          return const EmptyView(
            message: 'まだ記録がありません',
            icon: Icons.videogame_asset_outlined,
          );
        }
        return Column(
          children: [
            for (final entry in entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CoverImage(url: entry.gameCoverUrl, width: 44, height: 60),
                title: Text(entry.displayGameName),
                subtitle: Text(
                  entry.status == GameLogStatus.played ? '遊んだ' : '遊びたい',
                ),
                onTap: () => context.push('/games/${entry.gameId}'),
              ),
          ],
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
