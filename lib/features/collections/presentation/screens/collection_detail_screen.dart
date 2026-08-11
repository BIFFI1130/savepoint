import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/cover_image.dart';
import '../providers/collection_providers.dart';

class CollectionDetailScreen extends ConsumerWidget {
  const CollectionDetailScreen({super.key, required this.collectionId});

  final String collectionId;

  Future<void> _rename(BuildContext context, WidgetRef ref, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('コレクション名を編集'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == currentName) return;

    await ref.read(collectionRepositoryProvider).renameCollection(collectionId, name);
    ref.invalidate(collectionProvider(collectionId));
    ref.invalidate(myCollectionsProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('コレクションを削除しますか？'),
        content: const Text('このコレクション自体が削除されます（記録済みの評価やレビューは残ります）。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(collectionRepositoryProvider).deleteCollection(collectionId);
    ref.invalidate(myCollectionsProvider);
    if (context.mounted) context.pop();
  }

  Future<void> _removeGame(WidgetRef ref, int gameId) async {
    await ref.read(collectionRepositoryProvider).removeGame(collectionId, gameId);
    ref.invalidate(collectionGamesProvider(collectionId));
    ref.invalidate(collectionProvider(collectionId));
    ref.invalidate(myCollectionsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionAsync = ref.watch(collectionProvider(collectionId));
    final gamesAsync = ref.watch(collectionGamesProvider(collectionId));

    return Scaffold(
      appBar: AppBar(
        title: Text(collectionAsync.value?.name ?? 'コレクション'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'rename') {
                _rename(context, ref, collectionAsync.value?.name ?? '');
              } else if (value == 'delete') {
                _delete(context, ref);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'rename', child: Text('名前を編集')),
              PopupMenuItem(value: 'delete', child: Text('削除')),
            ],
          ),
        ],
      ),
      body: gamesAsync.when(
        data: (games) {
          if (games.isEmpty) {
            return const EmptyView(
              message: 'まだ作品が追加されていません\nゲーム詳細画面の「コレクションに追加」から登録できます',
              icon: Icons.videogame_asset_outlined,
            );
          }
          return ListView.separated(
            itemCount: games.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = games[index];
              return ListTile(
                leading: CoverImage(url: entry.game.coverUrl, width: 44, height: 60),
                title: Text(entry.game.displayName),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'コレクションから削除',
                  onPressed: () => _removeGame(ref, entry.game.id),
                ),
                onTap: () => context.push('/games/${entry.game.id}'),
              );
            },
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: '作品一覧の取得に失敗しました',
          onRetry: () => ref.invalidate(collectionGamesProvider(collectionId)),
        ),
      ),
    );
  }
}
