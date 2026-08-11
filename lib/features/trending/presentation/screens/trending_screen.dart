import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/advanced_filters_section.dart';
import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../game_log/domain/game_log_stats.dart';
import '../providers/trending_providers.dart';

class TrendingScreen extends StatefulWidget {
  const TrendingScreen({super.key});

  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> {
  bool _includeAdult = false;
  bool _isGridView = false;

  void _onIncludeAdultChanged(bool value) {
    setState(() => _includeAdult = value);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('トレンド'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'みんなが遊びたい'),
              Tab(text: 'みんなが遊んだ'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AdvancedFiltersSection(
                includeAdult: _includeAdult,
                onIncludeAdultChanged: _onIncludeAdultChanged,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                  icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                  tooltip: _isGridView ? 'リスト表示に切り替え' : 'グリッド表示に切り替え',
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _RankingList(
                    provider: trendingWantToPlayProvider,
                    includeAdult: _includeAdult,
                    countSuffix: '人が遊びたい',
                    countSelector: _wantToPlayCount,
                    emptyMessage: 'まだ「遊びたい」の記録がありません',
                    isGridView: _isGridView,
                  ),
                  _RankingList(
                    provider: trendingPlayedProvider,
                    includeAdult: _includeAdult,
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

class _RankingList extends ConsumerWidget {
  const _RankingList({
    required this.provider,
    required this.includeAdult,
    required this.countSuffix,
    required this.countSelector,
    required this.emptyMessage,
    required this.isGridView,
  });

  final FutureProviderFamily<List<GameLogStats>, bool> provider;
  final bool includeAdult;
  final String countSuffix;
  final int Function(GameLogStats) countSelector;
  final String emptyMessage;
  final bool isGridView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(provider(includeAdult));

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
                  return ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${index + 1}',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
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
        onRetry: () => ref.invalidate(provider(includeAdult)),
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
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.white,
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
