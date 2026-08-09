import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/cover_image.dart';
import '../providers/game_search_providers.dart';

class GameSearchScreen extends ConsumerWidget {
  const GameSearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(gameSearchProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ゲームを探す')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'タイトルで検索（例：ゼルダの伝説）',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  ref.read(gameSearchProvider.notifier).search(value),
            ),
          ),
          Expanded(
            child: resultsAsync.when(
              data: (games) {
                if (games.isEmpty) {
                  return const EmptyView(
                    message: 'ゲームタイトルを検索してみましょう',
                    icon: Icons.videogame_asset_outlined,
                  );
                }
                return ListView.separated(
                  itemCount: games.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final game = games[index];
                    return ListTile(
                      leading: CoverImage(
                        url: game.coverUrl,
                        width: 44,
                        height: 60,
                      ),
                      title: Text(game.name),
                      subtitle: game.releaseYear != null
                          ? Text('${game.releaseYear}年')
                          : null,
                      onTap: () => context.push('/games/${game.id}'),
                    );
                  },
                );
              },
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                message: 'ゲームの検索に失敗しました',
                onRetry: () => ref.invalidate(gameSearchProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
