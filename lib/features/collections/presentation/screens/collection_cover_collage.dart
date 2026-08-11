import 'package:flutter/material.dart';

import '../../../../core/widgets/cover_image.dart';

/// コレクション一覧カード用に、直近追加された最大4件のカバーを2x2で並べる。
/// 0件のときはプレースホルダーアイコンを表示する。
class CollectionCoverCollage extends StatelessWidget {
  const CollectionCoverCollage({super.key, required this.coverUrls});

  final List<String?> coverUrls;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(8);
    if (coverUrls.isEmpty) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.collections_bookmark_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 32,
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: GridView.count(
        crossAxisCount: 2,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        children: [
          for (var i = 0; i < 4; i++)
            i < coverUrls.length
                ? CoverImage(
                    url: coverUrls[i],
                    width: double.infinity,
                    height: double.infinity,
                  )
                : Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
        ],
      ),
    );
  }
}
