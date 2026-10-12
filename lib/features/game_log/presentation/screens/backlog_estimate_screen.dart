import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/config/app_links.dart';
import '../../../../core/utils/share_card_capture.dart';
import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../domain/backlog_estimate.dart';
import '../providers/log_providers.dart';
import '../widgets/backlog_share_card.dart';

/// 「遊びたい」に積んだゲームを、クリア時間から消化にかかる期間に換算して見せる画面。
class BacklogEstimateScreen extends ConsumerStatefulWidget {
  const BacklogEstimateScreen({super.key});

  @override
  ConsumerState<BacklogEstimateScreen> createState() =>
      _BacklogEstimateScreenState();
}

class _BacklogEstimateScreenState extends ConsumerState<BacklogEstimateScreen> {
  static const _hourOptions = [3.0, 5.0, 10.0, 20.0];
  static const _shortestShown = 5;

  double _hoursPerWeek = 5;
  bool _isSharing = false;
  final _shareKey = GlobalKey();

  String get _hoursLabel =>
      _hoursPerWeek.toStringAsFixed(_hoursPerWeek % 1 == 0 ? 0 : 1);

  Future<void> _share(BacklogEstimate estimate) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final span = describeWeeks(estimate.weeksToFinish(_hoursPerWeek));
      final shared = await shareBoundaryAsImage(
        boundaryKey: _shareKey,
        filePrefix: 'savepoint_backlog',
        text: 'SavePointで積みゲーを数えたら、週$_hoursLabel時間で消化に$spanかかる計算でした\n'
            '#積みゲー\n${AppLinks.shareFooter}',
      );
      if (shared) {
        await ref.read(appAnalyticsProvider).logShare(contentType: 'backlog');
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(myLogsProvider);
    final estimate = logsAsync.valueOrNull == null
        ? null
        : estimateBacklog(logsAsync.valueOrNull!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('積みゲー消化シミュレーター'),
        actions: [
          IconButton(
            icon: _isSharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_outlined),
            tooltip: '結果をシェア',
            onPressed: estimate != null && estimate.countedGames > 0
                ? () => _share(estimate)
                : null,
          ),
        ],
      ),
      body: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          logsAsync.when(
            data: (_) => _buildBody(context, estimate!),
            loading: () => const LoadingView(),
            error: (error, _) => ErrorView(
              message: '記録の取得に失敗しました',
              onRetry: () => ref.invalidate(myLogsProvider),
            ),
          ),
          // シェア画像用のカード。画面外に置いてもペイントはされる
          // （Offstage/Opacity(0)だとtoImageが空になるため使えない）。
          if (estimate != null && estimate.countedGames > 0)
            Positioned(
              left: -9999,
              top: 0,
              child: RepaintBoundary(
                key: _shareKey,
                child: BacklogShareCard(
                  estimate: estimate,
                  hoursPerWeek: _hoursPerWeek,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, BacklogEstimate estimate) {
    if (estimate.totalGames == 0) {
      return Column(
        children: [
          const Expanded(
            child: EmptyView(
              message: '「遊びたい」にゲームを追加すると、消化にかかる期間を計算できます',
              icon: Icons.hourglass_empty,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: OutlinedButton.icon(
              onPressed: () => context.push('/steam-import'),
              icon: const Icon(Icons.download_outlined),
              label: const Text('Steamの積みゲーを取り込む'),
            ),
          ),
        ],
      );
    }
    final theme = Theme.of(context);
    final span = describeWeeks(estimate.weeksToFinish(_hoursPerWeek));
    final shortest = estimate.entries.take(_shortestShown).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '週$_hoursLabel時間遊ぶと、積みゲーの完走まで',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  estimate.countedGames == 0 ? '計算できません' : span,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '積みゲー ${estimate.totalGames}本'
                  '${estimate.countedGames > 0 ? ' ／ 合計 約${estimate.totalHours.round()}時間' : ''}',
                  style: theme.textTheme.titleMedium,
                ),
                if (estimate.missingCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'クリア時間の情報がない${estimate.missingCount}本は、合計に含めていません',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('1週間に遊べる時間', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final hours in _hourOptions)
              ChoiceChip(
                label: Text('${hours.round()}時間'),
                selected: _hoursPerWeek == hours,
                onSelected: (_) => setState(() => _hoursPerWeek = hours),
              ),
          ],
        ),
        if (shortest.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('短い時間で遊べる順', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final item in shortest)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CoverImage(
                url: item.entry.game.coverUrl,
                width: 40,
                height: 56,
              ),
              title: Text(
                item.entry.game.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(_formatHours(item.hours)),
              onTap: () => context.push('/games/${item.entry.game.id}'),
            ),
        ],
      ],
    );
  }

  static String _formatHours(double hours) =>
      hours < 10 ? '約${hours.toStringAsFixed(1)}時間' : '約${hours.round()}時間';
}
