import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../subscription/subscription_providers.dart';
import 'genre_badge_selector.dart';

/// 絞り込みシート内の「ジャンルから探す」セクション。サブスク限定機能。
/// 未加入の場合はジャンル選択バッジの代わりに、サブスク加入ページへの誘導ボタンを表示する。
/// 検索・トレンド・マイログ・発売日カレンダーの絞り込みシートで共通して使う。
class GenreFilterSection extends ConsumerWidget {
  const GenreFilterSection({
    super.key,
    required this.selectedGenres,
    required this.onToggle,
  });

  final Set<String> selectedGenres;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSubscribed = ref.watch(isAdFreeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('ジャンルから探す', style: Theme.of(context).textTheme.labelMedium),
            if (!isSubscribed) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.lock_outline,
                size: 14,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (isSubscribed)
          GenreBadgeSelector(selectedGenres: selectedGenres, onToggle: onToggle)
        else
          OutlinedButton.icon(
            onPressed: () => context.push('/subscription/paywall'),
            icon: const Icon(Icons.workspace_premium_outlined),
            label: const Text('サブスクに加入してジャンルから探す'),
          ),
      ],
    );
  }
}
