import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/streak/app_open_streak_service.dart';
import '../../../../core/widgets/async_state_views.dart';
import '../../../collections/presentation/providers/collection_providers.dart';
import '../../../game_log/presentation/providers/log_providers.dart';
import '../../domain/achievement.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(myLogsProvider);
    final collectionsAsync = ref.watch(myCollectionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('実績')),
      body: logsAsync.when(
        data: (logs) => collectionsAsync.when(
          data: (collections) => _AchievementList(
            statuses: evaluateAchievements(logs, collections),
          ),
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            message: '実績の取得に失敗しました',
            onRetry: () => ref.invalidate(myCollectionsProvider),
          ),
        ),
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: '実績の取得に失敗しました',
          onRetry: () => ref.invalidate(myLogsProvider),
        ),
      ),
    );
  }
}

class _AchievementList extends StatelessWidget {
  const _AchievementList({required this.statuses});

  final List<AchievementStatus> statuses;

  @override
  Widget build(BuildContext context) {
    final unlockedCount = statuses.where((s) => s.achieved).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$unlockedCount / ${statuses.length} 達成',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const _AppOpenStreakBadge(),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: statuses.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) => _AchievementTile(status: statuses[index]),
          ),
        ),
      ],
    );
  }
}

/// アプリを開いた連続日数のバッジ。記録の有無を問わない指標なので、
/// 「記録ストリーク」（🔥）とは別のアイコン・文言にして混同を避ける。
class _AppOpenStreakBadge extends ConsumerWidget {
  const _AppOpenStreakBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(appOpenStreakProvider).valueOrNull ?? 0;
    if (streak <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('📅', style: TextStyle(fontSize: 14)),
        const SizedBox(width: 2),
        Text(
          '$streak日連続起動',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.status});

  final AchievementStatus status;

  @override
  Widget build(BuildContext context) {
    final achieved = status.achieved;
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            achieved ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
        child: Icon(
          status.achievement.icon,
          color: achieved ? colorScheme.onPrimaryContainer : colorScheme.outline,
        ),
      ),
      title: Text(
        status.achievement.title,
        style: TextStyle(color: achieved ? null : colorScheme.outline),
      ),
      subtitle: Text(_subtitle(status)),
      trailing: achieved
          ? IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'シェアする',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => _AchievementShareDialog(achievement: status.achievement),
              ),
            )
          : null,
    );
  }

  String _subtitle(AchievementStatus status) {
    if (!status.achieved) {
      final progress = status.currentProgress > status.achievement.target
          ? status.achievement.target
          : status.currentProgress;
      return '${status.achievement.description}（$progress/${status.achievement.target}）';
    }
    final achievedAt = status.achievedAt;
    if (achievedAt == null) return '達成済み';
    return '達成：${achievedAt.year}年${achievedAt.month}月${achievedAt.day}日';
  }
}

/// 達成済み実績のシェア用ダイアログ。カードを画像化してSNS等にシェアする
/// （`gamer_type_screen.dart`のRepaintBoundary→PNG→シェアという流れと同じパターン）。
class _AchievementShareDialog extends ConsumerStatefulWidget {
  const _AchievementShareDialog({required this.achievement});

  final Achievement achievement;

  @override
  ConsumerState<_AchievementShareDialog> createState() =>
      _AchievementShareDialogState();
}

class _AchievementShareDialogState extends ConsumerState<_AchievementShareDialog> {
  final _cardKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _share() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/savepoint_achievement_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'SavePointで実績「${widget.achievement.title}」を達成しました',
        ),
      );
      await ref.read(appAnalyticsProvider).logShare(contentType: 'achievement');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: _cardKey,
              child: _AchievementShareCard(achievement: widget.achievement),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isSharing ? null : _share,
              icon: _isSharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share),
              label: const Text('シェアする'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 実績シェア用のカード。画面表示・シェア画像の両方に使う。
class _AchievementShareCard extends StatelessWidget {
  const _AchievementShareCard({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 300,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, Color.lerp(colorScheme.primary, Colors.black, 0.35)!],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            'SavePoint 実績解放',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white24,
            child: Icon(achievement.icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            achievement.description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.6),
          ),
        ],
      ),
    );
  }
}
