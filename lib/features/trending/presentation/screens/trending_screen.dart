import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/advanced_filters_section.dart';
import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../../core/widgets/genre_badge_selector.dart';
import '../../../game_log/domain/game_log_stats.dart';
import '../../../social/presentation/providers/social_providers.dart';
import '../providers/trending_providers.dart';

class TrendingScreen extends ConsumerStatefulWidget {
  const TrendingScreen({super.key});

  @override
  ConsumerState<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends ConsumerState<TrendingScreen> {
  bool _includeAdult = false;
  // Riverpodのfamilyプロバイダーの引数として使うため、Setは常に新しいインスタンスに
  // 差し替える（同一インスタンスをin-placeでadd/removeすると、DartのSetは値の等価性を
  // 持たないためProviderが「引数が変わっていない」と誤認し、再フェッチされなくなる）。
  Set<String> _selectedGenres = {};
  bool _isGridView = false;

  bool get _hasActiveFilter => _includeAdult || _selectedGenres.isNotEmpty;

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
                                _selectedGenres = {};
                                _includeAdult = false;
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
    final filter = (includeAdult: _includeAdult, genres: _selectedGenres);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('トレンド'),
          actions: [
            IconButton(
              icon: Icon(
                _hasActiveFilter ? Icons.filter_alt : Icons.filter_alt_outlined,
                color: _hasActiveFilter ? Theme.of(context).colorScheme.primary : null,
              ),
              tooltip: '絞り込み',
              onPressed: _openFilterSheet,
            ),
            IconButton(
              onPressed: () => setState(() => _isGridView = !_isGridView),
              icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
              tooltip: _isGridView ? 'リスト表示に切り替え' : 'グリッド表示に切り替え',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'みんなが遊びたい'),
              Tab(text: 'みんなが遊んだ'),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [
                  _RankingList(
                    provider: trendingWantToPlayProvider,
                    filter: filter,
                    countSuffix: '人が遊びたい',
                    countSelector: _wantToPlayCount,
                    emptyMessage: 'まだ「遊びたい」の記録がありません',
                    isGridView: _isGridView,
                  ),
                  _RankingList(
                    provider: trendingPlayedProvider,
                    filter: filter,
                    countSuffix: '人が遊んだ',
                    countSelector: _playedCount,
                    emptyMessage: 'まだ「遊んだ」の記録がありません',
                    isGridView: _isGridView,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int _wantToPlayCount(GameLogStats stats) => stats.wantToPlayCount;
int _playedCount(GameLogStats stats) => stats.playedCount;

/// 1〜3位のメダルカラー（金・銀・銅）。4位以降は null（通常表示）。
const _medalColors = <int, Color>{
  1: Color(0xFFFFD700),
  2: Color(0xFFC0C0C0),
  3: Color(0xFFCD7F32),
};

class _RankingList extends ConsumerWidget {
  const _RankingList({
    required this.provider,
    required this.filter,
    required this.countSuffix,
    required this.countSelector,
    required this.emptyMessage,
    required this.isGridView,
  });

  final FutureProviderFamily<List<GameLogStats>, TrendingFilter> provider;
  final TrendingFilter filter;
  final String countSuffix;
  final int Function(GameLogStats) countSelector;
  final String emptyMessage;
  final bool isGridView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(provider(filter));

    return statsAsync.when(
      data: (stats) {
        if (stats.isEmpty) {
          return EmptyView(message: emptyMessage, icon: Icons.trending_up);
        }
        return isGridView
            ? GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemCount: stats.length,
                itemBuilder: (context, index) =>
                    _RankingGridItem(stat: stats[index], rank: index + 1),
              )
            : ListView.separated(
                itemCount: stats.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final stat = stats[index];
                  final rank = index + 1;
                  final medalColor = _medalColors[rank];
                  return ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '$rank',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: medalColor,
                                  fontWeight: medalColor != null ? FontWeight.bold : null,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CoverImage(url: stat.coverUrl, width: 40, height: 54),
                      ],
                    ),
                    title: Text(stat.displayName),
                    trailing: Text('${countSelector(stat)}$countSuffix'),
                    onTap: () => context.push('/games/${stat.gameId}'),
                  );
                },
              );
      },
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        message: 'ランキングの取得に失敗しました',
        onRetry: () => ref.invalidate(provider(filter)),
      ),
    );
  }
}

/// グリッド表示用の1件分（カバー画像に順位バッジを重ねる）。
class _RankingGridItem extends StatelessWidget {
  const _RankingGridItem({required this.stat, required this.rank});

  final GameLogStats stat;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final medalColor = _medalColors[rank];
    return GestureDetector(
      onTap: () => context.push('/games/${stat.gameId}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CoverImage(url: stat.coverUrl, width: double.infinity, height: double.infinity),
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: medalColor ?? Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: medalColor != null ? Colors.black : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
