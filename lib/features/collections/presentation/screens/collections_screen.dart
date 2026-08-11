import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/async_state_views.dart';
import '../providers/collection_providers.dart';
import 'collection_cover_collage.dart';

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  Future<void> _createCollection(BuildContext context, WidgetRef ref) async {
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
            child: const Text('作成'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    final id =
        await ref.read(collectionRepositoryProvider).createCollection(name);
    ref.invalidate(myCollectionsProvider);
    if (context.mounted) context.push('/collections/$id');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(myCollectionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('コレクション')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createCollection(context, ref),
        child: const Icon(Icons.add),
      ),
      body: collectionsAsync.when(
        data: (collections) {
          if (collections.isEmpty) {
            return const EmptyView(
              message: 'まだコレクションがありません\n右下の＋から作成できます',
              icon: Icons.collections_bookmark_outlined,
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: collections.length,
            itemBuilder: (context, index) {
              final collection = collections[index];
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.push('/collections/${collection.id}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CollectionCoverCollage(coverUrls: collection.coverUrls),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      collection.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '${collection.gameCount}件',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: 'コレクションの取得に失敗しました',
          onRetry: () => ref.invalidate(myCollectionsProvider),
        ),
      ),
    );
  }
}
