import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/game_search/domain/game.dart';
import 'cover_image.dart';

/// [showRank] 表示時に順位（trailing）が占める幅。桁数に関わらず固定することで、
/// タイトル表示領域の幅を全行で揃える。
const _rankColumnWidth = 32.0;

/// ゲーム一覧のリスト表示（Sliver）。検索結果・ホーム各セクションの一覧画面で共通して使う。
/// [showRank] を有効にすると、各行の先頭に順位（1始まり）を表示する（IGDB TOP100用）。
class GameSliverList extends StatelessWidget {
  const GameSliverList({
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
    return SliverList.separated(
      itemCount: games.length + (isLoadingMore ? 1 : 0),
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index >= games.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final game = games[index];
        return ListTile(
          leading: CoverImage(url: game.coverUrl, width: 44, height: 60),
          title: Text(
            game.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: game.releaseYear != null
              ? Text('${game.releaseYear}年')
              : null,
          trailing: showRank
              ? SizedBox(
                  width: _rankColumnWidth,
                  child: Text(
                    '${index + 1}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                )
              : null,
          onTap: () => context.push('/games/${game.id}'),
        );
      },
    );
  }
}
