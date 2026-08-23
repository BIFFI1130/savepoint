import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/release_countdown.dart';
import '../../../../core/widgets/advanced_filters_section.dart';
import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/avatar_image.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../../core/widgets/genre_filter_section.dart';
import '../../../../core/widgets/igdb_footer.dart';
import '../../../../core/widgets/star_rating.dart';
import '../../../favorites/presentation/providers/favorite_providers.dart';
import '../../../favorites/presentation/widgets/favorite_games_list.dart';
import '../../../game_search/domain/game.dart';
import '../../../social/presentation/providers/social_providers.dart';
import '../../domain/game_log.dart';
import '../providers/log_providers.dart';

enum MyLogSortType {
  addedOrder('追加した順'),
  rating('評価順'),
  name('名前順'),
  releaseDate('発売時期順'),
  priority('優先度順');

  const MyLogSortType(this.label);
  final String label;
}

String _backlogDaysLabel(DateTime createdAt) {
  final days = DateTime.now().difference(createdAt).inDays;
  return days <= 0 ? '今日追加' : '$days日間 積んでいます';
}

/// 「遊びたい」リストの1件に表示するステータス文言。未発売作品は発売日までの
/// 残り日数を優先して表示し（積みゲー扱いされると紛らわしいため）、発売済み・
/// 発売日不明の作品は従来通り登録からの経過日数を表示する。
String _wantToPlayStatusLabel(GameLog log, Game game) {
  return releaseCountdownLabel(game.firstReleaseDate) ??
      _backlogDaysLabel(log.createdAt);
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
  final Set<String> _selectedGenres = {};
  bool _isGridView = false;

  bool get _hasActiveFilter => _includeAdult || _selectedGenres.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        .where(
          (e) =>
              e.log.status == status &&
              (_includeAdult || !e.game.isAdult) &&
              (_selectedGenres.isEmpty ||
                  e.game.genres.any(_selectedGenres.contains)),
        )
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
        case MyLogSortType.priority:
          final aP = a.log.priority?.dbValue ?? 99;
          final bP = b.log.priority?.dbValue ?? 99;
          if (aP != bP) return aP.compareTo(bP);
          return b.log.createdAt.compareTo(a.log.createdAt);
      }
    });
    return filtered;
  }

  void _openFilterSheet() {
    final isAdultUser = ref.read(isAdultUserProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            void toggleGenre(String value) {
              setState(() {
                if (_selectedGenres.contains(value)) {
                  _selectedGenres.remove(value);
                } else {
                  _selectedGenres.add(value);
                }
              });
              setSheetState(() {});
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('絞り込み', style: Theme.of(context).textTheme.titleMedium),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedGenres.clear();
                                _includeAdult = false;
                              });
                              setSheetState(() {});
                            },
                            child: const Text('リセット'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GenreFilterSection(
                        selectedGenres: _selectedGenres,
                        onToggle: toggleGenre,
                      ),
                      AdvancedFiltersSection(
                        includeAdult: _includeAdult,
                        onIncludeAdultChanged: (value) {
                          setState(() => _includeAdult = value);
                          setSheetState(() {});
                        },
                        showAdultOption: isAdultUser,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(myLogsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('マイログ')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _ProfileHeader(),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _FollowCountsRow(),
          ),
          const Divider(height: 1),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '遊んだ'),
              Tab(text: '遊びたい'),
              Tab(text: 'オレの推しゲー'),
            ],
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _HubRow(),
          ),
          AnimatedBuilder(
            animation: _tabController.animation ?? _tabController,
            builder: (context, child) {
              final isFavoritesTab = _tabController.index == 2;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                child: Row(
                  children: [
                    if (!isFavoritesTab) ...[
                      Text(
                        '並び替え：',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<MyLogSortType>(
                        value: _sort,
                        isDense: true,
                        items: [
                          for (final type in MyLogSortType.values)
                            DropdownMenuItem(
                              value: type,
                              child: Text(type.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _sort = value);
                        },
                      ),
                    ],
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        _hasActiveFilter
                            ? Icons.filter_alt
                            : Icons.filter_alt_outlined,
                        color: _hasActiveFilter
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      tooltip: '絞り込み',
                      onPressed: _openFilterSheet,
                    ),
                    IconButton(
                      onPressed: () =>
                          setState(() => _isGridView = !_isGridView),
                      icon: Icon(
                        _isGridView ? Icons.view_list : Icons.grid_view,
                      ),
                      tooltip: _isGridView ? 'リスト表示に切り替え' : 'グリッド表示に切り替え',
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                logsAsync.when(
                  data: (logs) => _LogList(
                    logs: _filterAndSort(logs, GameLogStatus.played),
                    emptyMessage: 'まだ「遊んだ」記録がありません',
                    onRefresh: () => ref.refresh(myLogsProvider.future),
                    sortType: _sort,
                    isGridView: _isGridView,
                  ),
                  loading: () => const LoadingView(),
                  error: (error, _) => ErrorView(
                    message: 'ログの取得に失敗しました',
                    onRetry: () => ref.invalidate(myLogsProvider),
                  ),
                ),
                logsAsync.when(
                  data: (logs) => _LogList(
                    logs: _filterAndSort(logs, GameLogStatus.wantToPlay),
                    emptyMessage: 'まだ「遊びたい」に登録した作品がありません',
                    onRefresh: () => ref.refresh(myLogsProvider.future),
                    sortType: _sort,
                    isGridView: _isGridView,
                  ),
                  loading: () => const LoadingView(),
                  error: (error, _) => ErrorView(
                    message: 'ログの取得に失敗しました',
                    onRetry: () => ref.invalidate(myLogsProvider),
                  ),
                ),
                _MyFavoritesTab(isGridView: _isGridView),
              ],
            ),
          ),
          const IgdbFooter(),
        ],
      ),
    );
  }
}

/// 「オレの推しゲー」タブ。最大5件のお気に入り作品を、順位あり／順不同で表示する。
class _MyFavoritesTab extends ConsumerWidget {
  const _MyFavoritesTab({required this.isGridView});

  final bool isGridView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(myFavoritesProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(myFavoritesProvider.future),
      child: favoritesAsync.when(
        data: (favorites) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (favorites.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: EmptyView(
                    message: 'まだ推しゲーが登録されていません',
                    icon: Icons.favorite_border,
                  ),
                )
              else
                FavoriteGamesList(favorites: favorites, isGridView: isGridView),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.push('/favorites/edit'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('推しゲーを編集する'),
              ),
            ],
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: '推しゲーの取得に失敗しました',
          onRetry: () => ref.invalidate(myFavoritesProvider),
        ),
      ),
    );
  }
}

/// マイログ最上部のユーザーアイコン・ユーザー名。タップでプロフィール編集画面へ。
class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).valueOrNull;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/social/my-profile'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            AvatarImage(url: profile?.avatarUrl, radius: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                profile?.displayLabel ?? '名前未設定',
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

/// フォロー中／フォロワーの人数。タップでそれぞれの一覧画面へ遷移する。
class _FollowCountsRow extends ConsumerWidget {
  const _FollowCountsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingCount = ref.watch(followingListProvider).valueOrNull?.length;
    final followersCount = ref.watch(followersListProvider).valueOrNull?.length;
    return Row(
      children: [
        _FollowCountButton(
          count: followingCount,
          label: 'フォロー',
          onTap: () => context.push('/social'),
        ),
        const SizedBox(width: 20),
        _FollowCountButton(
          count: followersCount,
          label: 'フォロワー',
          onTap: () => context.push('/social/followers'),
        ),
      ],
    );
  }
}

class _FollowCountButton extends StatelessWidget {
  const _FollowCountButton({
    required this.count,
    required this.label,
    required this.onTap,
  });

  final int? count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${count ?? 0}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// マイログ画面の入り口として、コレクション・まとめ・実績への導線をまとめた横並びカード。
class _HubRow extends StatelessWidget {
  const _HubRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HubCard(
            icon: Icons.collections_bookmark_outlined,
            label: 'コレクション',
            onTap: () => context.push('/collections'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _HubCard(
            icon: Icons.bar_chart_outlined,
            label: 'まとめ',
            onTap: () => context.push('/summary'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _HubCard(
            icon: Icons.emoji_events_outlined,
            label: '実績',
            onTap: () => context.push('/achievements'),
          ),
        ),
      ],
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
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

    final useHeaders =
        sortType == MyLogSortType.name || sortType == MyLogSortType.releaseDate;

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
      child: useHeaders ? _buildGroupedList(context) : _buildFlatList(context),
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
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
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
      leading: CoverImage(url: entry.game.coverUrl, width: 44, height: 60),
      title: Text(
        entry.game.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWantToPlay)
            Row(
              children: [
                _PriorityChip(log: entry.log),
                const SizedBox(width: 8),
                Text(
                  _wantToPlayStatusLabel(entry.log, entry.game),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            )
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
      isThreeLine:
          !isWantToPlay &&
          entry.log.reviewText != null &&
          entry.log.reviewText!.isNotEmpty,
      onTap: () => context.push('/games/${entry.game.id}'),
    );
  }
}

/// 選択結果を表す。nullとの区別のため、シート自体を閉じただけの場合と
/// 「未設定」を選んだ場合（priorityがnull）を区別できるようラップする。
class _PriorityPick {
  const _PriorityPick(this.priority);
  final BacklogPriority? priority;
}

Color _priorityColor(BuildContext context, BacklogPriority priority) {
  switch (priority) {
    case BacklogPriority.high:
      return Colors.red;
    case BacklogPriority.medium:
      return Colors.orange;
    case BacklogPriority.low:
      return Theme.of(context).colorScheme.outline;
  }
}

/// 「遊びたい」リストの優先度チップ。タップで優先度を変更できる。
class _PriorityChip extends ConsumerWidget {
  const _PriorityChip({required this.log});

  final GameLog log;

  Future<void> _pickPriority(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<_PriorityPick>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final priority in BacklogPriority.values)
              ListTile(
                leading: Icon(
                  Icons.flag,
                  color: _priorityColor(sheetContext, priority),
                ),
                title: Text(priority.label),
                onTap: () =>
                    Navigator.pop(sheetContext, _PriorityPick(priority)),
              ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('未設定'),
              onTap: () =>
                  Navigator.pop(sheetContext, const _PriorityPick(null)),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    await ref.read(logRepositoryProvider).setPriority(log.id, result.priority);
    ref.invalidate(myLogsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priority = log.priority;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _pickPriority(context, ref),
      child: Chip(
        avatar: Icon(
          priority == null ? Icons.flag_outlined : Icons.flag,
          size: 16,
          color: priority == null ? null : _priorityColor(context, priority),
        ),
        label: Text(priority?.label ?? '優先度未設定'),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
