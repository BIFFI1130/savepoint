import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../../core/widgets/igdb_footer.dart';
import '../../../../core/widgets/star_rating.dart';
import '../../../game_log/domain/game_log.dart';
import '../../../game_log/presentation/providers/log_providers.dart';

/// 「遊んだ」記録を記録日の古い順に並べ、年ごとに区切って表示するタイムライン。
/// 自分が歩んできたゲーム人生を振り返る画面。
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(myLogsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ゲーム人生タイムライン')),
      body: logsAsync.when(
        data: (logs) {
          final played = logs
              .where((e) => e.log.status == GameLogStatus.played)
              .toList()
            ..sort((a, b) => a.log.createdAt.compareTo(b.log.createdAt));

          if (played.isEmpty) {
            return const EmptyView(
              message: '「遊んだ」記録を追加すると、\nここに歩んできた記録が並びます',
              icon: Icons.timeline,
            );
          }

          final groups = <int, List<GameLogWithGame>>{};
          for (final entry in played) {
            (groups[entry.log.createdAt.year] ??= []).add(entry);
          }
          final years = groups.keys.toList()..sort();

          return RefreshIndicator(
            onRefresh: () => ref.refresh(myLogsProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                for (final year in years) ...[
                  _YearHeader(year: year),
                  const SizedBox(height: 12),
                  for (var i = 0; i < groups[year]!.length; i++)
                    _TimelineEntry(
                      entry: groups[year]![i],
                      isLast: i == groups[year]!.length - 1,
                    ),
                  const SizedBox(height: 12),
                ],
                const IgdbFooter(),
              ],
            ),
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: 'タイムラインの取得に失敗しました',
          onRetry: () => ref.invalidate(myLogsProvider),
        ),
      ),
    );
  }
}

class _YearHeader extends StatelessWidget {
  const _YearHeader({required this.year});

  final int year;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$year年',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.entry, required this.isLast});

  final GameLogWithGame entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final date = entry.log.createdAt;
    final rating = entry.log.rating;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 16,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: InkWell(
                onTap: () => context.push('/games/${entry.game.id}'),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CoverImage(url: entry.game.coverUrl, width: 52, height: 72),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${date.month}月${date.day}日',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Text(
                            entry.game.displayName,
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (rating != null)
                                StarRating(rating: rating.toDouble(), size: 14),
                              if (entry.log.isCleared) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.flag_circle,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
