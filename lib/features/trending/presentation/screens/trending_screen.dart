import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../game_log/domain/game_log_stats.dart';
import '../providers/trending_providers.dart';

class TrendingScreen extends StatelessWidget {
  const TrendingScreen({super.key});

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
        body: TabBarView(
          children: [
            _RankingList(
              provider: trendingWantToPlayProvider,
              countSuffix: '人が遊びたい',
              countSelector: _wantToPlayCount,
              emptyMessage: 'まだ「遊びたい」の記録がありません',
            ),
            _RankingList(
              provider: trendingPlayedProvider,
              countSuffix: '人が遊んだ',
              countSelector: _playedCount,
              emptyMessage: 'まだ「遊んだ」の記録がありません',
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
    required this.countSuffix,
    required this.countSelector,
    required this.emptyMessage,
  });

  final FutureProvider<List<GameLogStats>> provider;
  final String countSuffix;
  final int Function(GameLogStats) countSelector;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(provider);

    return statsAsync.when(
      data: (stats) {
        if (stats.isEmpty) {
          return EmptyView(message: emptyMessage, icon: Icons.trending_up);
        }
        return ListView.separated(
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
              title: Text(stat.name),
              trailing: Text('${countSelector(stat)}$countSuffix'),
              onTap: () => context.push('/games/${stat.gameId}'),
            );
          },
        );
      },
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        message: 'ランキングの取得に失敗しました',
        onRetry: () => ref.invalidate(provider),
      ),
    );
  }
}
