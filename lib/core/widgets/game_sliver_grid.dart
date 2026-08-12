import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/game_search/domain/game.dart';
import 'cover_image.dart';

/// ゲーム一覧のグリッド表示（Sliver、1行3件・画像のみ）。検索結果・ホーム各セクションの
/// 一覧画面で共通して使う。[showRank] を有効にすると各カードの左上に順位（1始まり）
/// バッジを重ねて表示する（IGDB TOP100用）。
class GameSliverGrid extends StatelessWidget {
  const GameSliverGrid({
    super.key,
    required this.games,
    this.isLoadingMore = false,
    this.showRank = false,
  });

  final List<Game> games;
  final bool isLoadingMore;
  final bool showRank;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.7,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index >= games.length) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          final game = games[index];
          final cover = ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CoverImage(
              url: game.coverUrl,
              width: double.infinity,
              height: double.infinity,
            ),
          );
          return GestureDetector(
            onTap: () => context.push('/games/${game.id}'),
            child: showRank
                ? Stack(
                    children: [
                      cover,
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : cover,
          );
        }, childCount: games.length + (isLoadingMore ? 3 : 0)),
      ),
    );
  }
}
