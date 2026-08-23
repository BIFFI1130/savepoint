import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/cover_image.dart';
import '../../domain/favorite_game.dart';

/// 推しゲー一覧の表示（リスト／グリッド切り替え対応）。
/// カバー画像とともに、順位あり設定なら順位バッジ、順不同ならハートアイコンを重ねる。
class FavoriteGamesList extends StatelessWidget {
  const FavoriteGamesList({
    super.key,
    required this.favorites,
    required this.isGridView,
  });

  final List<FavoriteGameEntry> favorites;
  final bool isGridView;

  @override
  Widget build(BuildContext context) {
    if (isGridView) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.7,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemCount: favorites.length,
        itemBuilder: (context, index) =>
            _FavoriteGridItem(entry: favorites[index], index: index),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < favorites.length; i++)
          _FavoriteListTile(entry: favorites[i], index: i),
      ],
    );
  }
}

class _FavoriteBadge extends StatelessWidget {
  const _FavoriteBadge({required this.entry, required this.index});

  final FavoriteGameEntry entry;
  final int index;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 12,
      backgroundColor: entry.favoritesRanked
          ? Theme.of(context).colorScheme.primary
          : Colors.pink,
      foregroundColor: Colors.white,
      child: entry.favoritesRanked
          ? Text('${index + 1}', style: const TextStyle(fontSize: 12))
          : const Icon(Icons.favorite, size: 14),
    );
  }
}

class _FavoriteListTile extends StatelessWidget {
  const _FavoriteListTile({required this.entry, required this.index});

  final FavoriteGameEntry entry;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CoverImage(url: entry.gameCoverUrl, width: 44, height: 60),
            Positioned(
              left: -6,
              top: -6,
              child: _FavoriteBadge(entry: entry, index: index),
            ),
          ],
        ),
        title: Text(
          entry.displayGameName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => context.push('/games/${entry.gameId}'),
      ),
    );
  }
}

class _FavoriteGridItem extends StatelessWidget {
  const _FavoriteGridItem({required this.entry, required this.index});

  final FavoriteGameEntry entry;
  final int index;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/games/${entry.gameId}'),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CoverImage(
                url: entry.gameCoverUrl,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
          Positioned(
            left: 4,
            top: 4,
            child: _FavoriteBadge(entry: entry, index: index),
          ),
        ],
      ),
    );
  }
}
