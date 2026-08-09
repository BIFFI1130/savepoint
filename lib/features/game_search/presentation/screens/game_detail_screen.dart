import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/cover_image.dart';
import '../providers/game_search_providers.dart';

class GameDetailScreen extends ConsumerWidget {
  const GameDetailScreen({super.key, required this.gameId});

  final int gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameAsync = ref.watch(gameDetailsProvider(gameId));

    return Scaffold(
      appBar: AppBar(title: const Text('ゲーム詳細')),
      body: gameAsync.when(
        data: (game) {
          if (game == null) {
            return const ErrorView(message: 'ゲーム情報が見つかりませんでした');
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CoverImage(url: game.coverUrl, width: 140, height: 190),
                ),
                const SizedBox(height: 16),
                Text(game.name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (game.releaseYear != null)
                      Chip(label: Text('${game.releaseYear}年')),
                    for (final platform in game.platforms)
                      Chip(label: Text(platform)),
                  ],
                ),
                if (game.summary != null && game.summary!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('概要', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(game.summary!),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.push('/games/$gameId/log'),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('この作品を記録する'),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: 'ゲーム情報の取得に失敗しました',
          onRetry: () => ref.invalidate(gameDetailsProvider(gameId)),
        ),
      ),
    );
  }
}
