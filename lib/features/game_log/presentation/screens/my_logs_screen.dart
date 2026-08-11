import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/advanced_filters_section.dart';
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
  bool _includeAdult = false;
  bool _isGridView = false;

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
    final filtered = logs
        .where((e) =>
            e.log.status == status && (_includeAdult || !e.game.isAdult))
        .toList();
    filtered.sort((a, b) {
      switch (_sort) {
        case MyLogSortType.addedOrder:
          return b.log.createdAt.compareTo(a.log.createdAt);
        case MyLogSortType.rating:
          return (b.log.rating ?? 0).compareTo(a.log.rating ?? 0);
        case MyLogSortType.name:
          return a.game.displayName.compareTo(b.game.displayName);
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
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
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
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                  icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                  tooltip: _isGridView ? 'リスト表示に切り替え' : 'グリッド表示に切り替え',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AdvancedFiltersSection(
              includeAdult: _includeAdult,
              onIncludeAdultChanged: (value) =>
                  setState(() => _includeAdult = value),
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
                      sortType: _sort,
                      isGridView: _isGridView,
                    ),
                    _LogList(
                      logs: _filterAndSort(logs, GameLogStatus.wantToPlay),
                      emptyMessage: 'まだ「遊びたい」に登録した作品がありません',
                      onRefresh: () => ref.refresh(myLogsProvider.future),
                      sortType: _sort,
                      isGridView: _isGridView,
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
    required this.sortType,
    required this.isGridView,
  });

  final List<GameLogWithGame> logs;
  final String emptyMessage;
  final Future<void> Function() onRefresh;
  final MyLogSortType sortType;
  final bool isGridView;

  String? _sectionKey(GameLogWithGame entry) {
    switch (sortType) {
      case MyLogSortType.name:
        final name = entry.game.displayName;
        return name.isEmpty ? '' : name.characters.first;
      case MyLogSortType.releaseDate:
        final d = entry.game.firstReleaseDate;
        if (d == null) return '発売日不明';
        return '${d.year}年${d.month}月';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            EmptyView(message: emptyMessage, icon: Icons.bookmark_border),
          ],
        ),
      );
    }

    final useHeaders = sortType == MyLogSortType.name ||
        sortType == MyLogSortType.releaseDate;

    if (isGridView) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: useHeaders
            ? _buildGroupedGrid(context)
            : _buildFlatGrid(context),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: useHeaders
          ? _buildGroupedList(context)
          : _buildFlatList(context),
    );
  }

  List<(String, List<GameLogWithGame>)> _groupLogs() {
    final groups = <String, List<GameLogWithGame>>{};
    for (final entry in logs) {
      final key = _sectionKey(entry) ?? '';
      (groups[key] ??= []).add(entry);
    }
    return groups.entries.map((e) => (e.key, e.value)).toList();
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildFlatList(BuildContext context) {
    return ListView.separated(
      itemCount: logs.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) => _buildListTile(context, logs[index]),
    );
  }

  Widget _buildGroupedList(BuildContext context) {
    final groups = _groupLogs();
    return ListView.builder(
      itemCount: groups.fold<int>(0, (sum, g) => sum + 1 + g.$2.length),
      itemBuilder: (context, index) {
        var offset = 0;
        for (final (header, items) in groups) {
          if (index == offset) return _buildSectionHeader(context, header);
          offset++;
          if (index < offset + items.length) {
            return Column(
              children: [
                _buildListTile(context, items[index - offset]),
                if (index - offset < items.length - 1) const Divider(height: 1),
              ],
            );
          }
          offset += items.length;
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildFlatGrid(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: logs.length,
      itemBuilder: (context, index) => _buildGridItem(context, logs[index]),
    );
  }

  Widget _buildGroupedGrid(BuildContext context) {
    final groups = _groupLogs();
    return CustomScrollView(
      slivers: [
        for (final (header, items) in groups) ...[
          SliverToBoxAdapter(child: _buildSectionHeader(context, header)),
          SliverPadding(
            padding: const EdgeInsets.all(8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.7,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildGridItem(context, items[index]),
                childCount: items.length,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGridItem(BuildContext context, GameLogWithGame entry) {
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
  }

  Widget _buildListTile(BuildContext context, GameLogWithGame entry) {
    final isWantToPlay = entry.log.status == GameLogStatus.wantToPlay;
    return ListTile(
      leading: CoverImage(
        url: entry.game.coverUrl,
        width: 44,
        height: 60,
      ),
      title: Text(entry.game.displayName),
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
  }
}
