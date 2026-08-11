import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// ユーザーのアバター画像。丸型、読み込み中・取得失敗時はプレースホルダー。
class AvatarImage extends StatelessWidget {
  const AvatarImage({super.key, required this.url, this.radius = 20});

  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.person_outline,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: radius,
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      foregroundImage: CachedNetworkImageProvider(url!),
    );
  }
}
