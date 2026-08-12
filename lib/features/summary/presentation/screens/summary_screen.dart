import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../game_log/presentation/providers/log_providers.dart';
import '../../domain/period_summary.dart';

class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key});

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  SummaryPeriodType _periodType = SummaryPeriodType.month;
  late DateTime _periodStart = _currentPeriodStart(_periodType);

  DateTime _currentPeriodStart(SummaryPeriodType type) {
    final now = DateTime.now();
    return switch (type) {
      SummaryPeriodType.month => DateTime(now.year, now.month),
      SummaryPeriodType.year => DateTime(now.year),
      SummaryPeriodType.all => DateTime(now.year),
    };
  }

  bool get _isAtCurrentPeriod =>
      !_periodStart.isBefore(_currentPeriodStart(_periodType));

  void _changePeriodType(SummaryPeriodType type) {
    setState(() {
      _periodType = type;
      _periodStart = _currentPeriodStart(type);
    });
  }

  void _shiftPeriod(int direction) {
    setState(() {
      _periodStart = _periodType == SummaryPeriodType.month
          ? DateTime(_periodStart.year, _periodStart.month + direction)
          : DateTime(_periodStart.year + direction);
    });
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(myLogsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('まとめ')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<SummaryPeriodType>(
              segments: const [
                ButtonSegment(value: SummaryPeriodType.month, label: Text('月間')),
                ButtonSegment(value: SummaryPeriodType.year, label: Text('年間')),
                ButtonSegment(value: SummaryPeriodType.all, label: Text('すべて')),
              ],
              selected: {_periodType},
              onSelectionChanged: (selection) => _changePeriodType(selection.first),
            ),
          ),
          if (_periodType != SummaryPeriodType.all)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shiftPeriod(-1),
                ),
                Text(
                  _periodType == SummaryPeriodType.month
                      ? '${_periodStart.year}年${_periodStart.month}月'
                      : '${_periodStart.year}年',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _isAtCurrentPeriod ? null : () => _shiftPeriod(1),
                ),
              ],
            ),
          Expanded(
            child: logsAsync.when(
              data: (logs) {
                final summary = summarizePeriod(
                  logs,
                  periodStart: _periodStart,
                  periodType: _periodType,
                );
                return _SummaryBody(summary: summary);
              },
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                message: 'まとめの取得に失敗しました',
                onRetry: () => ref.invalidate(myLogsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({required this.summary});

  final PeriodSummary summary;

  @override
  Widget build(BuildContext context) {
    if (summary.playedCount == 0 && summary.wantToPlayAddedCount == 0) {
      return const EmptyView(
        message: 'この期間の記録はまだありません',
        icon: Icons.bar_chart_outlined,
      );
    }

    final average = summary.averageRating;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: '記録した本数',
                value: '${summary.playedCount}本',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: '遊びたいに追加',
                value: '${summary.wantToPlayAddedCount}本',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: '平均評価',
                value: average != null ? average.toStringAsFixed(1) : '-',
              ),
            ),
          ],
        ),
        if (summary.playedCount > 0) ...[
          if (summary.genreCounts.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('ジャンル分布', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _GenreBreakdown(genreCounts: summary.genreCounts),
          ],
          const SizedBox(height: 24),
          Text('この期間に記録した作品', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: summary.playedEntries.length,
            itemBuilder: (context, index) {
              final entry = summary.playedEntries[index];
              return GestureDetector(
                onTap: () => context.push('/games/${entry.game.id}'),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CoverImage(
                    url: entry.game.coverUrl,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// ジャンルごとの記録件数を多い順に棒グラフ表示する。上位8件のみ表示する。
class _GenreBreakdown extends StatelessWidget {
  const _GenreBreakdown({required this.genreCounts});

  final Map<String, int> genreCounts;

  @override
  Widget build(BuildContext context) {
    final entries = genreCounts.entries.take(8).toList();
    final maxCount = entries.isEmpty
        ? 0
        : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(entry.key, overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxCount == 0 ? 0 : entry.value / maxCount,
                      minHeight: 10,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text('${entry.value}', textAlign: TextAlign.end),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
