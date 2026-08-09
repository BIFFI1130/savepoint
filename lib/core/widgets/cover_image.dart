import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// ゲームのカバー画像。読み込み中・取得失敗時のプレースホルダー付き。
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.url,
    this.width = 64,
    this.height = 88,
  });

  final String? url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(6);
    if (url == null || url!.isEmpty) {
      return _placeholder(context, borderRadius);
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: url!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (context, _) => _placeholder(context, borderRadius),
        errorWidget: (context, _, error) => _placeholder(context, borderRadius),
      ),
    );
  }

  Widget _placeholder(BuildContext context, BorderRadius borderRadius) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius,
      ),
      child: Icon(
        Icons.videogame_asset_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
