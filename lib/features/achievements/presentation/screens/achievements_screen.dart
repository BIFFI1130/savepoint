import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          padding: const EdgeInsets.all(16),
          child: Text(
            '$unlockedCount / ${statuses.length} 達成',
            style: Theme.of(context).textTheme.titleMedium,
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
