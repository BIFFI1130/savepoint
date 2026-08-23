import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/avatar_image.dart';
import '../../domain/social_profile.dart';
import '../providers/social_providers.dart';

enum UserListMode { followers, blocked }

/// フォロワー／ブロック中ユーザーの一覧。用途はmodeで切り替える。
class UserListScreen extends ConsumerWidget {
  const UserListScreen({super.key, required this.mode});

  final UserListMode mode;

  String get _title => switch (mode) {
        UserListMode.followers => 'フォロワー',
        UserListMode.blocked => 'ブロック中のユーザー',
      };

  String get _emptyMessage => switch (mode) {
        UserListMode.followers => 'まだフォロワーがいません',
        UserListMode.blocked => 'ブロック中のユーザーはいません',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = switch (mode) {
      UserListMode.followers => followersListProvider,
      UserListMode.blocked => blockedUsersListProvider,
    };
    final usersAsync = ref.watch(provider);

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: usersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return EmptyView(
              message: _emptyMessage,
              icon: Icons.people_outline,
            );
          }
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final profile = users[index];
              return ListTile(
                leading: AvatarImage(url: profile.avatarUrl),
                title: Text(profile.publicDisplayLabel),
                trailing: mode == UserListMode.blocked
                    ? TextButton(
                        onPressed: () => _unblock(context, ref, profile),
                        child: const Text('解除'),
                      )
                    : null,
                onTap: () => context.push('/users/${profile.id}'),
              );
            },
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: '取得に失敗しました',
          onRetry: () => ref.invalidate(provider),
        ),
      ),
    );
  }

  Future<void> _unblock(
    BuildContext context,
    WidgetRef ref,
    SocialProfile profile,
  ) async {
    await ref.read(socialRepositoryProvider).unblockUser(profile.id);
    ref.invalidate(blockedUsersListProvider);
    ref.invalidate(isBlockedProvider(profile.id));
  }
}
