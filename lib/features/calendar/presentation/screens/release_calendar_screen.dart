import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/advanced_filters_section.dart';
import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../../core/widgets/genre_badge_selector.dart';
import '../../../game_search/domain/game.dart';
import '../../../game_search/domain/platform_options.dart';
import '../../../social/presentation/providers/social_providers.dart';
import '../providers/calendar_providers.dart';

const _weekdayLabels = ['日', '月', '火', '水', '木', '金', '土'];

/// 発売日をカレンダー形式（月表示）で見る画面。日付セルをタップすると、
/// その日発売のゲーム一覧をボトムシートで表示する。
/// 絞り込み条件はAppBarのアイコンから開くボトムシートに置き、本体はカレンダーが
/// 開いた瞬間から画面いっぱいに見えるようにしている。
class ReleaseCalendarScreen extends ConsumerStatefulWidget {
  const ReleaseCalendarScreen({super.key});

  @override
  ConsumerState<ReleaseCalendarScreen> createState() =>
      _ReleaseCalendarScreenState();
}

class _ReleaseCalendarScreenState
    extends ConsumerState<ReleaseCalendarScreen> {
  late DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  // Riverpodのfamilyプロバイダーの引数として使うため、Setは常に新しいインスタンスに
  // 差し替える（同一インスタンスをin-placeでadd/removeすると、DartのSetは値の等価性を
  // 持たないためProviderが「引数が変わっていない」と誤認し、再フェッチされなくなる）。
  Set<String> _selectedPlatforms = {};
  Set<String> _selectedGenres = {};
  bool _includeAdult = false;
  bool _includeIndie = false;

  bool get _hasActiveFilter =>
      _selectedPlatforms.isNotEmpty ||
      _selectedGenres.isNotEmpty ||
      _includeAdult ||
      _includeIndie;

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
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
                _selectedGenres = _selectedGenres.contains(value)
                    ? ({..._selectedGenres}..remove(value))
                    : ({..._selectedGenres}..add(value));
              });
              setSheetState(() {});
            }

            void togglePlatform(String value) {
              setState(() {
                _selectedPlatforms = _selectedPlatforms.contains(value)
                    ? ({..._selectedPlatforms}..remove(value))
                    : ({..._selectedPlatforms}..add(value));
              });
              setSheetState(() {});
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.95,
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
                                _selectedGenres = {};
                                _selectedPlatforms = {};
                                _includeAdult = false;
                                _includeIndie = false;
                              });
                              setSheetState(() {});
                            },
                            child: const Text('リセット'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('ジャンルから探す', style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: 8),
                      GenreBadgeSelector(
                        selectedGenres: _selectedGenres,
                        onToggle: toggleGenre,
                      ),
                      const SizedBox(height: 16),
                      Text('対応ハード', style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final option in platformOptions)
                            FilterChip(
                              label: Text(option.$1),
                              selected: _selectedPlatforms.contains(option.$2),
                              onSelected: (_) => togglePlatform(option.$2),
                            ),
                        ],
                      ),
                      AdvancedFiltersSection(
                        includeAdult: _includeAdult,
                        onIncludeAdultChanged: (value) {
                          setState(() => _includeAdult = value);
                          setSheetState(() {});
                        },
                        showAdultOption: isAdultUser,
                        includeIndie: _includeIndie,
                        onIncludeIndieChanged: (value) {
                          setState(() => _includeIndie = value);
                          setSheetState(() {});
                        },
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

  void _showDayGames(BuildContext context, DateTime date, List<Game> games) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${date.year}年${date.month}月${date.day}日発売（${games.length}件）',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: games.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final game = games[index];
                      return ListTile(
                        leading: CoverImage(url: game.coverUrl, width: 44, height: 60),
                        title: Text(game.displayName),
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push('/games/${game.id}');
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = (
      platforms: _selectedPlatforms,
      genres: _selectedGenres,
      includeAdult: _includeAdult,
      includeIndie: _includeIndie,
    );
    final request = (
      year: _visibleMonth.year,
      month: _visibleMonth.month,
      filter: filter,
    );
    final releasesAsync = ref.watch(calendarReleasesProvider(request));

    return Scaffold(
      appBar: AppBar(
        title: const Text('発売日カレンダー'),
        actions: [
          IconButton(
            icon: Icon(
              _hasActiveFilter ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _hasActiveFilter ? Theme.of(context).colorScheme.primary : null,
            ),
            tooltip: '絞り込み',
            onPressed: _openFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                  tooltip: '前の月',
                ),
                SizedBox(
                  width: 140,
                  child: Text(
                    '${_visibleMonth.year}年${_visibleMonth.month}月',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => _shiftMonth(1),
                  icon: const Icon(Icons.chevron_right),
                  tooltip: '次の月',
                ),
              ],
            ),
          ),
          Expanded(
            child: releasesAsync.when(
              data: (games) => _MonthGrid(
                month: _visibleMonth,
                games: games,
                onDayTap: _showDayGames,
              ),
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                message: 'カレンダーの取得に失敗しました',
                onRetry: () => ref.invalidate(calendarReleasesProvider(request)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 月表示のカレンダーグリッド（日曜始まり）。
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.games,
    required this.onDayTap,
  });

  final DateTime month;
  final List<Game> games;
  final void Function(BuildContext context, DateTime date, List<Game> games) onDayTap;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Dartのweekdayは月曜=1〜日曜=7。日曜始まりの週にするため%7で0〜6に変換する。
    final leadingBlanks = DateTime(month.year, month.month, 1).weekday % 7;

    final gamesByDay = <int, List<Game>>{};
    for (final game in games) {
      final date = game.firstReleaseDate;
      if (date == null || date.year != month.year || date.month != month.month) {
        continue;
      }
      gamesByDay.putIfAbsent(date.day, () => []).add(game);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              for (final label in _weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.72,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: leadingBlanks + daysInMonth,
            itemBuilder: (context, index) {
              if (index < leadingBlanks) return const SizedBox.shrink();
              final day = index - leadingBlanks + 1;
              final dayGames = gamesByDay[day] ?? const [];
              final today = DateTime.now();
              final isToday = today.year == month.year &&
                  today.month == month.month &&
                  today.day == day;
              return _DayCell(
                day: day,
                games: dayGames,
                isToday: isToday,
                onTap: dayGames.isEmpty
                    ? null
                    : () => onDayTap(
                          context,
                          DateTime(month.year, month.month, day),
                          dayGames,
                        ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.games,
    required this.isToday,
    this.onTap,
  });

  final int day;
  final List<Game> games;
  final bool isToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).dividerColor,
          ),
          color: isToday
              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4)
              : null,
        ),
        padding: const EdgeInsets.all(2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$day',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            if (games.isNotEmpty)
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: CoverImage(
                    url: games.first.coverUrl,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            if (games.length > 1)
              Text(
                '+${games.length - 1}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9),
              ),
          ],
        ),
      ),
    );
  }
}
