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
/// 「自分」「フォロー中」のチェックボックスで、どちらを表示するか（両方も可）を選べる。
class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  bool _includeMine = true;
  bool _includeFollowing = true;

  @override
  Widget build(BuildContext context) {
    final myLogsAsync = ref.watch(myLogsProvider);
    final followingFeedAsync = ref.watch(followingFeedProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              _FilterCheckbox(
                label: '自分',
                value: _includeMine,
                onChanged: (value) => setState(() => _includeMine = value),
              ),
              const SizedBox(width: 8),
              _FilterCheckbox(
                label: 'フォロー中',
                value: _includeFollowing,
                onChanged: (value) =>
                    setState(() => _includeFollowing = value),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _buildBody(context, myLogsAsync, followingFeedAsync),
        ),
        const IgdbFooter(),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncValue<List<GameLogWithGame>> myLogsAsync,
    AsyncValue<List<FollowFeedEntry>> followingFeedAsync,
  ) {
    if (!_includeMine && !_includeFollowing) {
      return const EmptyView(
        message: '「自分」か「フォロー中」を選択してください',
        icon: Icons.timeline,
      );
    }

    final activeAsyncs = [
      if (_includeMine) myLogsAsync,
      if (_includeFollowing) followingFeedAsync,
    ];
    if (activeAsyncs.any((async) => async.isLoading)) {
      return const LoadingView();
    }
    if (activeAsyncs.any((async) => async.hasError)) {
      return ErrorView(
        message: 'タイムラインの取得に失敗しました',
        onRetry: () {
          if (_includeMine) ref.invalidate(myLogsProvider);
          if (_includeFollowing) ref.invalidate(followingFeedProvider);
        },
      );
    }

    final entries = <_TimelineFeedEntry>[
      if (_includeMine)
        for (final entry in myLogsAsync.value ?? [])
          _TimelineFeedEntry.mine(entry),
      if (_includeFollowing)
        for (final entry in followingFeedAsync.value ?? [])
          _TimelineFeedEntry.following(entry),
    ];

    return _TimelineList(
      entries: entries,
      onRefresh: () async {
        await Future.wait([
          if (_includeMine) ref.refresh(myLogsProvider.future),
          if (_includeFollowing) ref.refresh(followingFeedProvider.future),
        ]);
      },
      emptyMessage: '「遊んだ」「遊びたい」に追加すると、\nここに記録が並びます',
    );
  }
}

/// 「自分」「フォロー中」の表示切り替え用チェックボックス。ラベルタップでも切り替わる。
class _FilterCheckbox extends StatelessWidget {
  const _FilterCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            onChanged: (checked) => onChanged(checked ?? false),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 2),
          Text(label),
        ],
      ),
    );
  }
}

/// 年ごとに区切った縦のタイムライン表示。[_MyTimelineTab]・[_FollowingTimelineTab]で共通利用する。
class _TimelineList extends StatelessWidget {
  const _TimelineList({
    required this.entries,
    required this.onRefresh,
    required this.emptyMessage,
  });

  final List<_TimelineFeedEntry> entries;
  final Future<void> Function() onRefresh;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            EmptyView(message: emptyMessage, icon: Icons.timeline),
          ],
        ),
      );
    }

    final sorted = [...entries]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final groups = <int, List<_TimelineFeedEntry>>{};
    for (final entry in sorted) {
      (groups[entry.createdAt.year] ??= []).add(entry);
    }
    final years = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: onRefresh,
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
