import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/subscription/subscription_providers.dart';
import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../../core/widgets/igdb_footer.dart';
import '../../../game_log/presentation/providers/log_providers.dart';
import '../../../game_search/domain/genre_options.dart';
import '../../../social/presentation/providers/social_providers.dart';
import '../../domain/period_summary.dart';

class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key});

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen>
    with SingleTickerProviderStateMixin {
  SummaryPeriodType _periodType = SummaryPeriodType.month;
  late DateTime _periodStart = _currentPeriodStart(_periodType);
  late final TabController _tabController =
      TabController(length: 3, vsync: this);
  final _shareCardKey = GlobalKey();
  PeriodSummary? _lastSummary;
  bool _isSharing = false;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 週間表示の開始日（その週の月曜日）。他機能（週間記録ストリーク等）と
  /// 同じ「月曜始まり」の考え方に揃えている。
  DateTime _weekStart(DateTime date) =>
      DateTime(date.year, date.month, date.day)
          .subtract(Duration(days: date.weekday - 1));

  DateTime _currentPeriodStart(SummaryPeriodType type) {
    final now = DateTime.now();
    return switch (type) {
      SummaryPeriodType.week => _weekStart(now),
      SummaryPeriodType.month => DateTime(now.year, now.month),
      SummaryPeriodType.year => DateTime(now.year),
      SummaryPeriodType.all => DateTime(now.year),
    };
  }

  bool get _isAtCurrentPeriod =>
      !_periodStart.isBefore(_currentPeriodStart(_periodType));

  void _changePeriodType(SummaryPeriodType type) {
    setState(() {
      _periodType = type;
      _periodStart = _currentPeriodStart(type);
    });
  }

  void _shiftPeriod(int direction) {
    setState(() {
      _periodStart = switch (_periodType) {
        SummaryPeriodType.week =>
          _periodStart.add(Duration(days: 7 * direction)),
        SummaryPeriodType.month =>
          DateTime(_periodStart.year, _periodStart.month + direction),
        SummaryPeriodType.year || SummaryPeriodType.all =>
          DateTime(_periodStart.year + direction),
      };
    });
  }

  String get _periodLabel => switch (_periodType) {
        SummaryPeriodType.week =>
          '${_periodStart.year}年${_periodStart.month}月${_periodStart.day}日の週',
        SummaryPeriodType.month => '${_periodStart.year}年${_periodStart.month}月',
        SummaryPeriodType.year => '${_periodStart.year}年',
        SummaryPeriodType.all => 'すべての記録',
      };

  Future<void> _shareSummary() async {
    final summary = _lastSummary;
    if (summary == null || _isSharing) return;
    setState(() => _isSharing = true);
    try {
      final boundary = _shareCardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/savepoint_summary_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'SavePointでの記録をシェア（$_periodLabel）',
        ),
      );
      await ref.read(appAnalyticsProvider).logShare(contentType: 'summary');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(myLogsProvider);
    // ボタンの有効/無効判定には、このbuild内で確実に最新のlogsAsyncを使う。
    // _lastSummaryはbody（下のlogsAsync.when内）で更新されるが、AppBarはbodyより
    // 先に構築されるため、_lastSummaryだけで判定すると常に1フレーム古い値を見てしまい、
    // かつ以降フィールド代入だけではrebuildが起きないため、ボタンが永久に無効化されたままになる。
    final hasSummaryData = logsAsync.hasValue;

    return Scaffold(
      appBar: AppBar(
        title: const Text('まとめ'),
        actions: [
          IconButton(
            icon: _isSharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_outlined),
            tooltip: '振り返りをシェア',
            onPressed: hasSummaryData ? _shareSummary : null,
          ),
        ],
      ),
      body: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SegmentedButton<SummaryPeriodType>(
                  segments: const [
                    ButtonSegment(value: SummaryPeriodType.week, label: Text('週間')),
                    ButtonSegment(value: SummaryPeriodType.month, label: Text('月間')),
                    ButtonSegment(value: SummaryPeriodType.year, label: Text('年間')),
                    ButtonSegment(value: SummaryPeriodType.all, label: Text('すべて')),
                  ],
                  selected: {_periodType},
                  onSelectionChanged: (selection) => _changePeriodType(selection.first),
                ),
              ),
              if (_periodType != SummaryPeriodType.all)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _shiftPeriod(-1),
                    ),
                    Text(_periodLabel, style: Theme.of(context).textTheme.titleMedium),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _isAtCurrentPeriod ? null : () => _shiftPeriod(1),
                    ),
                  ],
                ),
              const Divider(height: 1),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                tabs: const [
                  Tab(text: '記録'),
                  Tab(text: 'フォロー内ランキング'),
                  Tab(text: 'プレイ傾向診断'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    logsAsync.when(
                      data: (logs) {
                        final summary = summarizePeriod(
                          logs,
                          periodStart: _periodStart,
                          periodType: _periodType,
                        );
                        _lastSummary = summary;
                        return _SummaryBody(summary: summary);
                      },
                      loading: () => const LoadingView(),
                      error: (error, _) => ErrorView(
                        message: 'まとめの取得に失敗しました',
                        onRetry: () => ref.invalidate(myLogsProvider),
                      ),
                    ),
                    const _LeaderboardTab(),
                    _GamerTypeTab(onTap: () => context.push('/summary/gamer-type')),
                  ],
                ),
              ),
              const IgdbFooter(),
            ],
          ),
          // シェア用の画像カード。画面の外（Stackのクリップ範囲外）に配置することで、
          // ユーザーには見えないが実際にペイントはされる状態を保つ。
          // OffstageやOpacity(0)は子を一切ペイントしないため、
          // RepaintBoundary.toImage()が空/壊れた画像を返してしまうので使えない。
          if (_lastSummary != null)
            Positioned(
              left: -9999,
              top: 0,
              child: RepaintBoundary(
                key: _shareCardKey,
                child: _ShareCard(
                  periodLabel: _periodLabel,
                  summary: _lastSummary!,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 「フォロー内ランキング」タブの中身。期間選択（週間/月間/年間/すべて）とは
/// 独立して、常に直近7日固定で表示する。
class _LeaderboardTab extends ConsumerWidget {
  const _LeaderboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(followFeedLeaderboardProvider);
    return leaderboardAsync.when(
      data: (entries) {
        if (entries.isEmpty) {
          return const EmptyView(
            message: 'フォロー中のユーザーの記録がまだありません',
            icon: Icons.leaderboard_outlined,
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: const [_LeaderboardCard()],
        );
      },
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        message: 'ランキングの取得に失敗しました',
        onRetry: () => ref.invalidate(followFeedLeaderboardProvider),
      ),
    );
  }
}

/// 「プレイ傾向診断」タブの中身。診断結果は別画面（gamer-type）に持つため、
/// ここは導線カードのみを表示する。
class _GamerTypeTab extends StatelessWidget {
  const _GamerTypeTab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Text('🎮', style: TextStyle(fontSize: 24)),
          title: const Text('プレイ傾向診断'),
          subtitle: const Text('あなたのゲーマータイプを診断してシェアしよう'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// フォロー内リーダーボード（直近7日間の記録数ランキング上位5名）。
/// 期間選択（週間/月間/年間/すべて）とは独立して、常に直近7日固定で表示する。
class _LeaderboardCard extends ConsumerWidget {
  const _LeaderboardCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(followFeedLeaderboardProvider);
    final entries = leaderboardAsync.valueOrNull ?? const [];
    if (leaderboardAsync.hasValue && entries.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'フォロー内ランキング（今週）',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (!leaderboardAsync.hasValue)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              for (var i = 0; i < entries.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Text(
                    '${i + 1}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  title: Text(entries[i].displayLabel),
                  trailing: Text('${entries[i].logCount}本'),
                  onTap: () => context.push('/users/${entries[i].userId}'),
                ),
          ],
        ),
      ),
    );
  }
}

/// 「まとめ」画面の内容をSNS等に共有するための、ブランドカラーで統一した
/// 縦長カード（9:16、Instagram Stories等にそのまま使えるサイズ感）。
/// 画面表示用の[_SummaryBody]とは別に、共有専用に見た目を作り込んでいる。
class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.periodLabel, required this.summary});

  final String periodLabel;
  final PeriodSummary summary;

  static const _bgLight = Color(0xFF5A74FF);
  static const _bgDark = Color(0xFF2836C8);

  @override
  Widget build(BuildContext context) {
    final average = summary.averageRating;
    final topGenres = summary.genreCounts.entries.take(4).toList();
    final covers = summary.playedEntries.take(6).toList();

    return Container(
      width: 360,
      height: 640,
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_bgLight, _bgDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SavePoint',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            periodLabel,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              _ShareStat(value: '${summary.playedCount}', label: '記録した本数'),
              const SizedBox(width: 20),
              _ShareStat(
                value: average != null ? average.toStringAsFixed(1) : '-',
                label: '平均評価',
              ),
              const SizedBox(width: 20),
              _ShareStat(
                value: '${summary.wantToPlayAddedCount}',
                label: '遊びたいに追加',
              ),
            ],
          ),
          if (covers.isNotEmpty) ...[
            const SizedBox(height: 32),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: covers.length,
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CoverImage(
                    url: covers[index].game.coverUrl,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            ),
          ] else
            const Spacer(),
          if (topGenres.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in topGenres)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      entry.key,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ShareStat extends StatelessWidget {
  const _ShareStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}

class _SummaryBody extends ConsumerWidget {
  const _SummaryBody({required this.summary});

  final PeriodSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (summary.playedCount == 0 && summary.wantToPlayAddedCount == 0) {
      return const EmptyView(
        message: 'この期間の記録はまだありません',
        icon: Icons.bar_chart_outlined,
      );
    }

    final isAdFree = ref.watch(isAdFreeProvider);
    final average = summary.averageRating;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: '記録した本数',
                value: '${summary.playedCount}本',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: '遊びたいに追加',
                value: '${summary.wantToPlayAddedCount}本',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: '平均評価',
                value: average != null ? average.toStringAsFixed(1) : '-',
              ),
            ),
          ],
        ),
        if (summary.playedCount > 0) ...[
          if (summary.genreCounts.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('ジャンル分布', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _GenreBreakdown(genreCounts: summary.genreCounts),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Text('詳細統計', style: Theme.of(context).textTheme.titleMedium),
              if (!isAdFree) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (isAdFree)
            _DetailedStats(summary: summary)
          else
            OutlinedButton.icon(
              onPressed: () => context.push('/subscription/paywall'),
              icon: const Icon(Icons.workspace_premium_outlined),
              label: const Text('サブスクに加入して詳細な統計グラフを見る'),
            ),
          const SizedBox(height: 24),
          Text('この期間に記録した作品', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: summary.playedEntries.length,
            itemBuilder: (context, index) {
              final entry = summary.playedEntries[index];
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
            },
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// ジャンル表示ラベルから対応表のアイコン・色を引く。対応表に無い場合はデフォルト値を返す。
(IconData icon, Color color) _genreIconAndColor(String label) {
  final option = genreOptions
      .cast<(String, String, IconData, Color)?>()
      .firstWhere((o) => o!.$1 == label, orElse: () => null);
  return (option?.$3 ?? Icons.sports_esports, option?.$4 ?? Colors.grey);
}

/// ジャンルごとの記録件数を多い順に縦棒グラフで表示する。上位8件のみ表示する。
/// ラベルは専用アイコンのバッジ（文字無し）のみを並べ、タップするとジャンル名を表示する。
class _GenreBreakdown extends StatelessWidget {
  const _GenreBreakdown({required this.genreCounts});

  final Map<String, int> genreCounts;

  static const double _barAreaHeight = 120;

  @override
  Widget build(BuildContext context) {
    final entries = genreCounts.entries.take(8).toList();
    final maxCount = entries.isEmpty
        ? 0
        : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final entry in entries)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${entry.value}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: maxCount == 0
                        ? 4
                        : (_barAreaHeight - 20) * entry.value / maxCount,
                    decoration: BoxDecoration(
                      color: _genreIconAndColor(entry.key).$2,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _GenreIconBadge(label: entry.key, count: entry.value),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// ジャンルの専用アイコンのみを表示する正方形バッジ。タップするとジャンル名をSnackBarで表示する。
class _GenreIconBadge extends StatelessWidget {
  const _GenreIconBadge({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _genreIconAndColor(label);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label：$count本'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

/// サブスク特典「統計の詳細グラフ化」。評価の内訳と、期間内の記録数推移をまとめる。
class _DetailedStats extends StatelessWidget {
  const _DetailedStats({required this.summary});

  final PeriodSummary summary;

  @override
  Widget build(BuildContext context) {
    final hasRatings = summary.ratingCounts.values.any((c) => c > 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasRatings) ...[
          Text('評価の内訳', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _RatingBreakdown(ratingCounts: summary.ratingCounts),
          const SizedBox(height: 20),
        ],
        if (summary.periodType != SummaryPeriodType.week &&
            summary.periodType != SummaryPeriodType.month) ...[
          Text('記録数の推移', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _TrendChart(summary: summary),
        ],
      ],
    );
  }
}

/// 星1〜5ごとの記録件数を縦棒グラフで表示する。
class _RatingBreakdown extends StatelessWidget {
  const _RatingBreakdown({required this.ratingCounts});

  final Map<int, int> ratingCounts;

  static const double _barAreaHeight = 100;

  @override
  Widget build(BuildContext context) {
    final maxCount = ratingCounts.values.isEmpty
        ? 0
        : ratingCounts.values.reduce((a, b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var star = 1; star <= 5; star++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${ratingCounts[star] ?? 0}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: maxCount == 0
                        ? 4
                        : (_barAreaHeight - 20) *
                            (ratingCounts[star] ?? 0) /
                            maxCount,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$star', style: Theme.of(context).textTheme.labelSmall),
                      const Icon(Icons.star, size: 12, color: Colors.amber),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 期間内の記録数推移。年間表示は月ごと（1〜12月）、すべて表示は年ごとに集計する。
/// 月間表示は期間が短すぎて推移として意味を持たないため呼び出し側で表示しない。
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.summary});

  final PeriodSummary summary;

  static const double _barAreaHeight = 100;

  Map<String, int> _buckets() {
    final counts = <String, int>{};
    if (summary.periodType == SummaryPeriodType.year) {
      for (var month = 1; month <= 12; month++) {
        counts['$month月'] = 0;
      }
      for (final entry in summary.playedEntries) {
        final key = '${entry.log.createdAt.month}月';
        counts[key] = (counts[key] ?? 0) + 1;
      }
    } else {
      if (summary.playedEntries.isEmpty) return {};
      final years = summary.playedEntries.map((e) => e.log.createdAt.year);
      final minYear = years.reduce((a, b) => a < b ? a : b);
      final maxYear = years.reduce((a, b) => a > b ? a : b);
      for (var year = minYear; year <= maxYear; year++) {
        counts['$year'] = 0;
      }
      for (final entry in summary.playedEntries) {
        final key = '${entry.log.createdAt.year}';
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final buckets = _buckets();
    if (buckets.isEmpty) return const SizedBox.shrink();
    final maxCount = buckets.values.reduce((a, b) => a > b ? a : b);
    final entries = buckets.entries.toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${entry.value}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 20,
                    height: maxCount == 0
                        ? 4
                        : (_barAreaHeight - 20) * entry.value / maxCount,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(entry.key, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
