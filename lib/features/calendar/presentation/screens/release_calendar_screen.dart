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

enum _CalendarViewMode { daily, month }

/// 時刻部分を切り捨て、年月日だけのDateTimeにする。
DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

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
  _CalendarViewMode _viewMode = _CalendarViewMode.daily;
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
            child: SegmentedButton<_CalendarViewMode>(
              segments: const [
                ButtonSegment(
                  value: _CalendarViewMode.daily,
                  label: Text('デイリー'),
                  icon: Icon(Icons.view_carousel),
                ),
                ButtonSegment(
                  value: _CalendarViewMode.month,
                  label: Text('月間'),
                  icon: Icon(Icons.calendar_view_month),
                ),
              ],
              selected: {_viewMode},
              onSelectionChanged: (selection) =>
                  setState(() => _viewMode = selection.first),
            ),
          ),
          Expanded(
            child: _viewMode == _CalendarViewMode.daily
                ? _DailyView(
                    filter: filter,
                    onDayTap: _showDayGames,
                  )
                : _MonthView(
                    month: _visibleMonth,
                    filter: filter,
                    onShiftMonth: _shiftMonth,
                    onDayTap: _showDayGames,
                  ),
          ),
        ],
      ),
    );
  }
}

class _MonthView extends ConsumerWidget {
  const _MonthView({
    required this.month,
    required this.filter,
    required this.onShiftMonth,
    required this.onDayTap,
  });

  final DateTime month;
  final CalendarFilter filter;
  final void Function(int delta) onShiftMonth;
  final void Function(BuildContext context, DateTime date, List<Game> games) onDayTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = (year: month.year, month: month.month, filter: filter);
    final releasesAsync = ref.watch(calendarReleasesProvider(request));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => onShiftMonth(-1),
                icon: const Icon(Icons.chevron_left),
                tooltip: '前の月',
              ),
              SizedBox(
                width: 140,
                child: Text(
                  '${month.year}年${month.month}月',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: () => onShiftMonth(1),
                icon: const Icon(Icons.chevron_right),
                tooltip: '次の月',
              ),
            ],
          ),
        ),
        Expanded(
          child: releasesAsync.when(
            data: (games) => _MonthGrid(
              month: month,
              games: games,
              onDayTap: onDayTap,
            ),
            loading: () => const LoadingView(),
            error: (error, _) => ErrorView(
              message: 'カレンダーの取得に失敗しました',
              onRetry: () => ref.invalidate(calendarReleasesProvider(request)),
            ),
          ),
        ),
      ],
    );
  }
}

/// デイリー表示。中央に選択中の日、その左右に±1日分のカードがほぼ全体、
/// さらに外側（±2日）が半分ほど見える形で並ぶカルーセル。左右スワイプで日付を移動する。
/// カード自体はPageControllerのviewportFractionで並びを作り、中央からの距離に応じて
/// 縮小・半透明にすることで「今どの日にフォーカスしているか」を分かりやすくしている。
class _DailyView extends ConsumerStatefulWidget {
  const _DailyView({required this.filter, required this.onDayTap});

  final CalendarFilter filter;
  final void Function(BuildContext context, DateTime date, List<Game> games) onDayTap;

  @override
  ConsumerState<_DailyView> createState() => _DailyViewState();
}

class _DailyViewState extends ConsumerState<_DailyView> {
  // 中央のカードに対して左右1枚ずつがほぼ全体、その外側が少し見えるようにする。
  // カード間の隙間を詰めた分、この値を0.25よりわずかに大きくしてカバー画像自体を
  // 大きく見せている。
  static const _viewportFraction = 0.28;
  // 前後 約68年分。実質無制限に近い範囲を、負のインデックスを扱わずに済むよう
  // 大きな固定ページ数として確保する。
  static const _totalPages = 50000;
  static const _windowDays = 31;
  static const _windowMarginDays = 8;

  late final DateTime _today = _dateOnly(DateTime.now());
  late final DateTime _epoch = _today.subtract(const Duration(days: _totalPages ~/ 2));
  late final int _todayPage = _totalPages ~/ 2;
  late final PageController _controller =
      PageController(viewportFraction: _viewportFraction, initialPage: _todayPage);
  late DateTime _centerDay = _today;
  late DateTime _windowStart = _centerDay.subtract(const Duration(days: _windowDays ~/ 2));
  // 表示ウィンドウが変わって再取得（loading）になっている間もPageViewを維持したまま
  // 表示し続けるためのキャッシュ。ここが無いと、再取得のたびにreleasesAsync.whenの
  // loading分岐でPageViewごと差し替えられ、PageControllerのスクロール位置（＝現在の
  // 選択日）が失われて毎回「今日」に戻ってしまう。
  List<Game>? _cachedGames;

  DateTime _dayForPage(int page) => _epoch.add(Duration(days: page));

  void _onPageChanged(int page) {
    final day = _dayForPage(page);
    final windowEnd = _windowStart.add(const Duration(days: _windowDays));
    final needsNewWindow = day.difference(_windowStart).inDays < _windowMarginDays ||
        windowEnd.difference(day).inDays < _windowMarginDays;
    setState(() {
      _centerDay = day;
      if (needsNewWindow) {
        _windowStart = day.subtract(const Duration(days: _windowDays ~/ 2));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = (rangeStart: _windowStart, days: _windowDays, filter: widget.filter);
    final releasesAsync = ref.watch(calendarRangeReleasesProvider(request));
    ref.listen(calendarRangeReleasesProvider(request), (previous, next) {
      next.whenData((games) => setState(() => _cachedGames = games));
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '${_centerDay.year}年${_centerDay.month}月${_centerDay.day}日'
            '（${_weekdayLabels[_centerDay.weekday % 7]}）',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              final games = _cachedGames;
              // ウィンドウ切り替えの再取得中（loading）でも、既に一度データを取得済み
              // なら古いデータのままPageViewを維持し続ける（スクロール位置を失わないため）。
              // 初回読み込み・エラー時のみ専用ビューに切り替える。
              if (games == null) {
                if (releasesAsync.hasError) {
                  return ErrorView(
                    message: 'カレンダーの取得に失敗しました',
                    onRetry: () => ref.invalidate(calendarRangeReleasesProvider(request)),
                  );
                }
                return const LoadingView();
              }
              final gamesByDay = <DateTime, List<Game>>{};
              for (final game in games) {
                final date = game.firstReleaseDate;
                if (date == null) continue;
                gamesByDay.putIfAbsent(_dateOnly(date), () => []).add(game);
              }
              return PageView.builder(
                controller: _controller,
                itemCount: _totalPages,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, page) {
                  final date = _dayForPage(page);
                  final dayGames = gamesByDay[date] ?? const [];
                  return _DailyCarouselItem(
                    controller: _controller,
                    page: page,
                    child: _DailyCard(
                      date: date,
                      games: dayGames,
                      isToday: date == _today,
                      onTap: dayGames.isEmpty
                          ? null
                          : () {
                              final currentPage =
                                  _controller.page?.round() ?? _todayPage;
                              if (page == currentPage) {
                                widget.onDayTap(context, date, dayGames);
                              } else {
                                _controller.animateToPage(
                                  page,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              }
                            },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// [page] とスクロール位置との距離に応じて、カードを縮小・半透明にする。
/// 中央に近いほど大きく・不透明に、外側（±2日目）ほど小さく・薄くなる。
class _DailyCarouselItem extends StatelessWidget {
  const _DailyCarouselItem({
    required this.controller,
    required this.page,
    required this.child,
  });

  final PageController controller;
  final int page;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        var distance = 0.0;
        if (controller.position.haveDimensions) {
          final currentPage = controller.page;
          if (currentPage != null) distance = (currentPage - page).abs();
        }
        final scale = (1 - distance * 0.22).clamp(0.55, 1.0);
        final opacity = (1 - distance * 0.35).clamp(0.35, 1.0);
        return Align(
          alignment: Alignment.topCenter,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(scale: scale, alignment: Alignment.topCenter, child: child),
          ),
        );
      },
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({
    required this.date,
    required this.games,
    required this.isToday,
    this.onTap,
  });

  final DateTime date;
  final List<Game> games;
  final bool isToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final topGame = games.isEmpty ? null : games.first;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isToday
              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${_weekdayLabels[date.weekday % 7]} ${date.month}/${date.day}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            if (topGame != null) ...[
              // ゲームのカバー画像は縦長（おおよそ3:4）が一般的なので、カードの幅
              // いっぱいまで使ってできるだけ大きく表示する。
              AspectRatio(
                aspectRatio: 3 / 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CoverImage(
                    url: topGame.coverUrl,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                topGame.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              if (games.length > 1)
                Text(
                  '他${games.length - 1}件',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  '発売なし',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
          ],
        ),
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
