import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../../core/widgets/igdb_footer.dart';
import '../../../../core/widgets/star_rating.dart';
import '../../../game_log/domain/game_log.dart';
import '../../../game_log/presentation/providers/log_providers.dart';
import '../../../social/domain/follow_feed_entry.dart';
import '../../../social/presentation/providers/social_providers.dart';

/// 自分とフォロー中ユーザーの「遊んだ／遊びたい」への追加を、追加日時の新しい順に
/// 年ごとに区切って表示するタイムライン。ホーム画面の「タイムライン」タブの中身。
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myLogsAsync = ref.watch(myLogsProvider);
    final followingFeedAsync = ref.watch(followingFeedProvider);

    if (myLogsAsync.isLoading || followingFeedAsync.isLoading) {
      return const LoadingView();
    }
    if (myLogsAsync.hasError) {
      return ErrorView(
        message: 'タイムラインの取得に失敗しました',
        onRetry: () => ref.invalidate(myLogsProvider),
      );
    }
    if (followingFeedAsync.hasError) {
      return ErrorView(
        message: 'タイムラインの取得に失敗しました',
        onRetry: () => ref.invalidate(followingFeedProvider),
      );
    }

    final entries = <_TimelineFeedEntry>[
      for (final entry in myLogsAsync.value ?? [])
        _TimelineFeedEntry.mine(entry),
      for (final entry in followingFeedAsync.value ?? [])
        _TimelineFeedEntry.following(entry),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (entries.isEmpty) {
      return const EmptyView(
        message: '「遊んだ」「遊びたい」に追加すると、\nここに自分とフォロー中ユーザーの記録が並びます',
        icon: Icons.timeline,
      );
    }

    final groups = <int, List<_TimelineFeedEntry>>{};
    for (final entry in entries) {
      (groups[entry.createdAt.year] ??= []).add(entry);
    }
    final years = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: () => Future.wait([
        ref.refresh(myLogsProvider.future),
        ref.refresh(followingFeedProvider.future),
      ]),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          for (final year in years) ...[
            _YearHeader(year: year),
            const SizedBox(height: 12),
            for (var i = 0; i < groups[year]!.length; i++)
              _TimelineEntryTile(
                entry: groups[year]![i],
                isLast: i == groups[year]!.length - 1,
              ),
            const SizedBox(height: 12),
          ],
          const IgdbFooter(),
        ],
      ),
    );
  }
}

/// 自分の記録（[GameLogWithGame]）とフォロー中ユーザーの記録（[FollowFeedEntry]）を
/// 同じ形で扱うための統一エントリ。
class _TimelineFeedEntry {
  const _TimelineFeedEntry({
    required this.gameId,
    required this.gameName,
    this.coverUrl,
    required this.status,
    required this.createdAt,
    required this.isMine,
    required this.userLabel,
    this.rating,
    this.isCleared = false,
  });

  factory _TimelineFeedEntry.mine(GameLogWithGame entry) {
    return _TimelineFeedEntry(
      gameId: entry.game.id,
      gameName: entry.game.displayName,
      coverUrl: entry.game.coverUrl,
      status: entry.log.status,
      createdAt: entry.log.createdAt,
      isMine: true,
      userLabel: '自分',
      rating: entry.log.rating,
      isCleared: entry.log.isCleared,
    );
  }

  factory _TimelineFeedEntry.following(FollowFeedEntry entry) {
    return _TimelineFeedEntry(
      gameId: entry.gameId,
      gameName: entry.displayGameName,
      coverUrl: entry.gameCoverUrl,
      status: entry.status,
      createdAt: entry.createdAt,
      isMine: false,
      userLabel: entry.userLabel,
      rating: entry.rating,
      isCleared: entry.isCleared,
    );
  }

  final int gameId;
  final String gameName;
  final String? coverUrl;
  final GameLogStatus status;
  final DateTime createdAt;
  final bool isMine;
  final String userLabel;
  final double? rating;
  final bool isCleared;
}

class _YearHeader extends StatelessWidget {
  const _YearHeader({required this.year});

  final int year;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$year年',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
      ),
    );
  }
}

class _TimelineEntryTile extends StatelessWidget {
  const _TimelineEntryTile({required this.entry, required this.isLast});

  final _TimelineFeedEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final date = entry.createdAt;
    final outline = Theme.of(context).colorScheme.outline;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 16,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: InkWell(
                onTap: () => context.push('/games/${entry.gameId}'),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CoverImage(url: entry.coverUrl, width: 52, height: 72),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${date.month}月${date.day}日',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              if (!entry.isMine) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    entry.userLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            entry.gameName,
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                entry.status == GameLogStatus.played
                                    ? Icons.videogame_asset
                                    : Icons.bookmark_outline,
                                size: 14,
                                color: outline,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                entry.status == GameLogStatus.played
                                    ? '遊んだ'
                                    : '遊びたい',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(color: outline),
                              ),
                              if (entry.rating != null) ...[
                                const SizedBox(width: 8),
                                StarRating(rating: entry.rating!, size: 14),
                              ],
                              if (entry.isCleared) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.flag_circle,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
