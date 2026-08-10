import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../../core/widgets/star_rating.dart';
import '../../domain/game_log.dart';
import '../providers/log_providers.dart';

enum MyLogSortType {
  addedOrder('追加した順'),
  rating('評価順'),
  name('名前順'),
  releaseDate('発売時期順');

  const MyLogSortType(this.label);
  final String label;
}

class MyLogsScreen extends ConsumerStatefulWidget {
  const MyLogsScreen({super.key});

  @override
  ConsumerState<MyLogsScreen> createState() => _MyLogsScreenState();
}

class _MyLogsScreenState extends ConsumerState<MyLogsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  MyLogSortType _sort = MyLogSortType.addedOrder;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<GameLogWithGame> _filterAndSort(
    List<GameLogWithGame> logs,
    GameLogStatus status,
  ) {
    final filtered = logs.where((e) => e.log.status == status).toList();
    filtered.sort((a, b) {
      switch (_sort) {
        case MyLogSortType.addedOrder:
          return b.log.createdAt.compareTo(a.log.createdAt);
        case MyLogSortType.rating:
          return (b.log.rating ?? 0).compareTo(a.log.rating ?? 0);
        case MyLogSortType.name:
          return a.game.name.compareTo(b.game.name);
        case MyLogSortType.releaseDate:
          final aDate = a.game.firstReleaseDate;
          final bDate = b.game.firstReleaseDate;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
      }
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(myLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('マイログ'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '遊んだ'),
            Tab(text: '遊びたい'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Text('並び替え：', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(width: 8),
                DropdownButton<MyLogSortType>(
                  value: _sort,
                  isDense: true,
                  items: [
                    for (final type in MyLogSortType.values)
                      DropdownMenuItem(value: type, child: Text(type.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _sort = value);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: logsAsync.when(
              data: (logs) {
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _LogList(
                      logs: _filterAndSort(logs, GameLogStatus.played),
                      emptyMessage: 'まだ「遊んだ」記録がありません',
                      onRefresh: () => ref.refresh(myLogsProvider.future),
                    ),
                    _LogList(
                      logs: _filterAndSort(logs, GameLogStatus.wantToPlay),
                      emptyMessage: 'まだ「遊びたい」に登録した作品がありません',
                      onRefresh: () => ref.refresh(myLogsProvider.future),
                    ),
                  ],
                );
              },
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                message: 'ログの取得に失敗しました',
                onRetry: () => ref.invalidate(myLogsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogList extends StatelessWidget {
  const _LogList({
    required this.logs,
    required this.emptyMessage,
    required this.onRefresh,
  });

  final List<GameLogWithGame> logs;
  final String emptyMessage;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: logs.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 120),
                EmptyView(message: emptyMessage, icon: Icons.bookmark_border),
              ],
            )
          : ListView.separated(
              itemCount: logs.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = logs[index];
                final isWantToPlay = entry.log.status == GameLogStatus.wantToPlay;
                return ListTile(
                  leading: CoverImage(
                    url: entry.game.coverUrl,
                    width: 44,
                    height: 60,
                  ),
                  title: Text(entry.game.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isWantToPlay)
                        const Text('遊びたい')
                      else if (entry.log.rating != null)
                        Row(
                          children: [
                            StarRating(rating: entry.log.rating!.toDouble(), size: 16),
                            if (entry.log.hasSpoiler) ...[
                              const SizedBox(width: 6),
                              const Chip(
                                label: Text('ネタバレ'),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ],
                        ),
                      if (!isWantToPlay &&
                          entry.log.reviewText != null &&
                          entry.log.reviewText!.isNotEmpty)
                        Text(
                          entry.log.reviewText!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                  isThreeLine: !isWantToPlay &&
                      entry.log.reviewText != null &&
                      entry.log.reviewText!.isNotEmpty,
                  onTap: () => context.push('/games/${entry.game.id}'),
                );
              },
            ),
    );
  }
}
