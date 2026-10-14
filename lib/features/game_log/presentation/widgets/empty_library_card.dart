import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 記録がまだ1件も無いユーザー向けの、最初の一歩を案内するカード。
/// 登録直後のホームと、記録が空のマイログに出す。
/// 記録の入口として一番手間が少ない「Steamからの一括取り込み」を前面に出す。
class EmptyLibraryCard extends StatelessWidget {
  const EmptyLibraryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.videogame_asset_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ゲームを記録しはじめよう',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Steamで持っているゲームを、まとめて追加できます。'
              '遊んだゲームも、まだ遊んでいない積みゲーも、これで一気に記録できます。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.push('/steam-import'),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Steamから取り込む'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '下の「検索」タブから、1本ずつ記録することもできます。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
