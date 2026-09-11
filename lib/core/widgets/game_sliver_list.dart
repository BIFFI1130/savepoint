import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/game_search/domain/game.dart';
import '../ads/native_ad_card.dart';
import 'cover_image.dart';

/// [showRank] 表示時に順位（trailing）が占める幅。桁数に関わらず固定することで、
/// タイトル表示領域の幅を全行で揃える。
const _rankColumnWidth = 32.0;

/// 広告行の高さ。ネイティブ広告カードの見出し・CTA・スクリム等が収まる最低限の高さ。
const _nativeAdRowHeight = 120.0;

/// ゲーム一覧のリスト表示（Sliver）。検索結果・ホーム各セクションの一覧画面で共通して使う。
/// [showRank] を有効にすると、各行の先頭に順位（1始まり）を表示する（IGDB TOP100用）。
/// [showNativeAd] を有効にすると、一覧の序盤に1件だけネイティブ広告行を紛れ込ませる。
class GameSliverList extends StatelessWidget {
  const GameSliverList({
    super.key,
    required this.games,
    this.isLoadingMore = false,
    this.showRank = false,
    this.showNativeAd = false,
  });

  final List<Game> games;
  final bool isLoadingMore;
  final bool showRank;
  final bool showNativeAd;

  // 何件目（0始まり）に広告行を挟むか。
  static const _nativeAdPosition = 3;

  @override
  Widget build(BuildContext context) {
    final adIndex =
        showNativeAd && games.length > _nativeAdPosition ? _nativeAdPosition : null;
    final itemCount = games.length + (adIndex != null ? 1 : 0) + (isLoadingMore ? 1 : 0);

    return SliverList.separated(
      itemCount: itemCount,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (adIndex != null && index == adIndex) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              child: SizedBox(
                height: _nativeAdRowHeight,
                child: NativeAdCard(width: double.infinity, height: _nativeAdRowHeight),
              ),
            ),
          );
        }
        final gameIndex = adIndex != null && index > adIndex ? index - 1 : index;
        if (gameIndex >= games.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final game = games[gameIndex];
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
                    '${gameIndex + 1}',
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
