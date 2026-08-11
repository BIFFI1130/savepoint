import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/collection_providers.dart';

/// ゲーム詳細画面から開く、コレクションへの追加・削除用ボトムシート。
class CollectionPickerSheet extends ConsumerWidget {
  const CollectionPickerSheet({super.key, required this.gameId});

  final int gameId;

  static Future<void> show(BuildContext context, int gameId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => CollectionPickerSheet(gameId: gameId),
    );
  }

  Future<void> _toggle(WidgetRef ref, String collectionId, bool nowSelected) async {
    final repo = ref.read(collectionRepositoryProvider);
    if (nowSelected) {
      await repo.addGame(collectionId, gameId);
    } else {
      await repo.removeGame(collectionId, gameId);
    }
    ref.invalidate(collectionsForGameProvider(gameId));
    ref.invalidate(myCollectionsProvider);
    ref.invalidate(collectionGamesProvider(collectionId));
  }

  Future<void> _createAndAdd(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新しいコレクション'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例：積みゲー'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('作成して追加'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    final repo = ref.read(collectionRepositoryProvider);
    final id = await repo.createCollection(name);
    await repo.addGame(id, gameId);
    ref.invalidate(myCollectionsProvider);
    ref.invalidate(collectionsForGameProvider(gameId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(myCollectionsProvider);
    final selectedAsync = ref.watch(collectionsForGameProvider(gameId));

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('コレクションに追加', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            collectionsAsync.when(
              data: (collections) {
                final selected = selectedAsync.value ?? const <String>{};
                if (collections.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('まだコレクションがありません'),
                  );
                }
                return Column(
                  children: [
                    for (final collection in collections)
                      CheckboxListTile(
                        value: selected.contains(collection.id),
                        title: Text(collection.name),
                        subtitle: Text('${collection.gameCount}件'),
                        onChanged: (value) =>
                            _toggle(ref, collection.id, value ?? false),
                      ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('コレクションの取得に失敗しました'),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('新しいコレクションを作成'),
              onTap: () => _createAndAdd(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
