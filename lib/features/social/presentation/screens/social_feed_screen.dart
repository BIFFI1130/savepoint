import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/avatar_image.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../game_log/domain/game_log.dart';
import '../providers/social_providers.dart';

/// 「つながり」タブのトップ画面。フォロー中ユーザーの活動フィードと、
/// ユーザー検索・プロフィール設定・フォロー中／フォロワー・ブロック中一覧への入り口。
class SocialFeedScreen extends ConsumerWidget {
  const SocialFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(followFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('つながり'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search_outlined),
            tooltip: 'ユーザーを探す',
            onPressed: () => context.push('/social/search'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  context.push('/social/profile-settings');
                case 'following':
                  context.push('/social/following');
                case 'followers':
                  context.push('/social/followers');
                case 'blocked':
                  context.push('/social/blocked');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'profile', child: Text('プロフィール設定')),
              PopupMenuItem(value: 'following', child: Text('フォロー中')),
              PopupMenuItem(value: 'followers', child: Text('フォロワー')),
              PopupMenuItem(value: 'blocked', child: Text('ブロック中のユーザー')),
            ],
          ),
        ],
      ),
      body: feedAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.refresh(followFeedProvider.future),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  EmptyView(
                    message:
                        'フォロー中のユーザーはいません\n右上の検索アイコンからユーザーを探してみましょう',
                    icon: Icons.people_outline,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(followFeedProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return ListTile(
                  leading: AvatarImage(url: entry.avatarUrl, radius: 20),
                  title: Text(entry.userLabel),
                  subtitle: Row(
                    children: [
                      CoverImage(
                        url: entry.gameCoverUrl,
                        width: 28,
                        height: 38,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${entry.displayGameName}を'
                          '${entry.status == GameLogStatus.played ? "遊んだ" : "遊びたい"}'
                          'に追加',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: false,
                  onTap: () => context.push('/users/${entry.userId}'),
                );
              },
            ),
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: 'フィードの取得に失敗しました',
          onRetry: () => ref.invalidate(followFeedProvider),
        ),
      ),
    );
  }
}
