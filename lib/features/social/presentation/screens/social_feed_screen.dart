import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/avatar_image.dart';
import '../providers/social_providers.dart';

/// 「つながり」タブのトップ画面。フォロー中ユーザーの一覧と、
/// ユーザー検索・フォロワー・ブロック中一覧への入り口。
/// プロフィール設定はマイログ画面の歯車アイコンから行う。
class SocialFeedScreen extends ConsumerWidget {
  const SocialFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsync = ref.watch(followingListProvider);

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
                case 'followers':
                  context.push('/social/followers');
                case 'blocked':
                  context.push('/social/blocked');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'followers', child: Text('フォロワー')),
              PopupMenuItem(value: 'blocked', child: Text('ブロック中のユーザー')),
            ],
          ),
        ],
      ),
      body: followingAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.refresh(followingListProvider.future),
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
            onRefresh: () => ref.refresh(followingListProvider.future),
            child: ListView.separated(
              itemCount: users.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final profile = users[index];
                return ListTile(
                  leading: AvatarImage(url: profile.avatarUrl),
                  title: Text(profile.displayLabel),
                  subtitle: profile.username != null
                      ? Text('@${profile.username}')
                      : null,
                  onTap: () => context.push('/users/${profile.id}'),
                );
              },
            ),
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: 'フォロー中一覧の取得に失敗しました',
          onRetry: () => ref.invalidate(followingListProvider),
        ),
      ),
    );
  }
}
