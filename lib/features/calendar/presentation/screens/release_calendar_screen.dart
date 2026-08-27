import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ads/banner_ad_widget.dart';
import '../../../../core/preferences/content_filter_prefs.dart';
import '../../../../core/subscription/subscription_providers.dart';
import '../../../../core/widgets/advanced_filters_section.dart';
import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../../core/widgets/genre_filter_section.dart';
import '../../../../core/widgets/igdb_footer.dart';
import '../../../game_search/domain/game.dart';
import '../../../game_search/domain/platform_options.dart';
import '../../../social/presentation/providers/social_providers.dart';
import '../providers/calendar_providers.dart';

const _weekdayLabels = ['日', '月', '火', '水', '木', '金', '土'];

/// 時刻部分を切り捨て、年月日だけのDateTimeにする。
DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// 発売日をデイリーカルーセルで見る画面。日付ヘッダーをタップすると月間カレンダーで
/// 日付にジャンプできる。カードをタップすると、その日発売のゲーム一覧をボトムシートで
/// 表示する。絞り込み条件はAppBarのアイコンから開くボトムシートに置いている。
class ReleaseCalendarScreen extends ConsumerStatefulWidget {
  const ReleaseCalendarScreen({super.key});

  @override
  ConsumerState<ReleaseCalendarScreen> createState() =>
      _ReleaseCalendarScreenState();
}

class _ReleaseCalendarScreenState
    extends ConsumerState<ReleaseCalendarScreen> {
  // Riverpodのfamilyプロバイダーの引数として使うため、Setは常に新しいインスタンスに
  // 差し替える（同一インスタンスをin-placeでadd/removeすると、DartのSetは値の等価性を
  // 持たないためProviderが「引数が変わっていない」と誤認し、再フェッチされなくなる）。
  Set<String> _selectedPlatforms = {};
  Set<String> _selectedGenres = {};
  bool _matchAllGenres = false;
  late bool _includeAdult;
  late bool _includeIndie;

  bool get _hasActiveFilter =>
      _selectedPlatforms.isNotEmpty ||
      _selectedGenres.isNotEmpty ||
      _includeAdult ||
      !_includeIndie;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(contentFilterPrefsProvider);
    _includeAdult = prefs.includeAdult;
    _includeIndie = prefs.includeIndie;
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
                                _matchAllGenres = false;
                                _selectedPlatforms = {};
                                _includeAdult = false;
                                _includeIndie = true;
                              });
                              final prefs = ref.read(contentFilterPrefsProvider);
                              prefs.setIncludeAdult(false);
                              prefs.setIncludeIndie(true);
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
                        matchAllGenres: _matchAllGenres,
                        onMatchAllChanged: (value) {
                          setState(() => _matchAllGenres = value);
                          setSheetState(() {});
                        },
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
                          ref.read(contentFilterPrefsProvider).setIncludeAdult(value);
                          setSheetState(() {});
                        },
                        showAdultOption: isAdultUser,
                        includeIndie: _includeIndie,
                        onIncludeIndieChanged: (value) {
                          setState(() => _includeIndie = value);
                          ref.read(contentFilterPrefsProvider).setIncludeIndie(value);
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
                        title: Text(
                          game.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
      matchAllGenres: _matchAllGenres,
    );

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: Icon(
              _hasActiveFilter ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _hasActiveFilter ? Theme.of(context).colorScheme.primary : null,
            ),
            tooltip: '絞り込み',
            onPressed: _openFilterSheet,
          ),
        ),
        Expanded(
          child: _DailyView(
            filter: filter,
            onDayTap: _showDayGames,
          ),
        ),
        if (!ref.watch(isAdFreeProvider)) const BannerAdWidget(),
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
  // 中央のカードを画面のほとんどを使うくらい大きく、その左右はごくわずかだけ覗く程度に留める。
  static const _viewportFraction = 0.66;
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

  Future<void> _openMonthPicker() async {
    final firstDate = _epoch;
    final lastDate = _epoch.add(const Duration(days: _totalPages - 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _centerDay,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: '日付を選択',
    );
    if (picked == null) return;
    final page = _dateOnly(picked).difference(_epoch).inDays;
    final currentPage = _controller.page?.round() ?? _todayPage;
    if ((page - currentPage).abs() <= 14) {
      _controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _controller.jumpToPage(page);
    }
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
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _openMonthPicker,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_centerDay.year}年${_centerDay.month}月${_centerDay.day}日'
                    '（${_weekdayLabels[_centerDay.weekday % 7]}）',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.calendar_month,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
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
        const IgdbFooter(),
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
        final scale = (1 - distance * 0.3).clamp(0.4, 1.0);
        final opacity = (1 - distance * 0.5).clamp(0.2, 1.0);
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${_weekdayLabels[date.weekday % 7]} ${date.month}/${date.day}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            if (topGame != null) ...[
              // ゲームのカバー画像は縦長（おおよそ3:4）が一般的。幅基準の固定サイズだと
              // カルーセルの縦幅が狭い場面（横向き・バナー広告追加時等）で画像が
              // 見切れてしまうため、LayoutBuilderで使える幅・高さ両方を見た上で、
              // 3:4を保ったまま収まる最大サイズを計算する。
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    var boxWidth = constraints.maxWidth;
                    var boxHeight = boxWidth * 4 / 3;
                    if (boxHeight > constraints.maxHeight) {
                      boxHeight = constraints.maxHeight;
                      boxWidth = boxHeight * 3 / 4;
                    }
                    return Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CoverImage(
                          url: topGame.coverUrl,
                          width: boxWidth,
                          height: boxHeight,
                        ),
                      ),
                    );
                  },
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

