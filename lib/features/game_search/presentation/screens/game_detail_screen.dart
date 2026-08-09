import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../../core/widgets/star_rating.dart';
import '../../../game_log/domain/game_log.dart';
import '../../../game_log/presentation/providers/log_providers.dart';
import '../../domain/game.dart';
import '../providers/game_search_providers.dart';

class GameDetailScreen extends ConsumerStatefulWidget {
  const GameDetailScreen({super.key, required this.gameId});

  final int gameId;

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen> {
  bool _showOriginalSummary = false;
  bool _isUpdatingStatus = false;

  Future<void> _markWantToPlay() async {
    setState(() => _isUpdatingStatus = true);
    try {
      await ref.read(logRepositoryProvider).markWantToPlay(widget.gameId);
      ref.invalidate(existingLogProvider(widget.gameId));
      ref.invalidate(myLogsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('更新に失敗しました')));
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameAsync = ref.watch(gameDetailsProvider(widget.gameId));
    final logAsync = ref.watch(existingLogProvider(widget.gameId));

    return Scaffold(
      appBar: AppBar(title: const Text('ゲーム詳細')),
      body: gameAsync.when(
        data: (game) {
          if (game == null) {
            return const ErrorView(message: 'ゲーム情報が見つかりませんでした');
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CoverImage(url: game.coverUrl, width: 140, height: 190),
                ),
                const SizedBox(height: 16),
                Text(game.name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                if (game.developers.isNotEmpty || game.publishers.isNotEmpty)
                  Text(
                    _companyLine(game),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (game.releaseYear != null)
                      Chip(label: Text('${game.releaseYear}年')),
                    for (final platform in game.platforms)
                      Chip(label: Text(platform)),
                  ],
                ),
                if (game.displaySummary != null && game.displaySummary!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('概要', style: Theme.of(context).textTheme.titleMedium),
                      if (game.summaryJa != null && game.summary != null)
                        TextButton(
                          onPressed: () => setState(
                            () => _showOriginalSummary = !_showOriginalSummary,
                          ),
                          child: Text(_showOriginalSummary ? '日本語訳を表示' : '原文を表示'),
                        ),
                    ],
                  ),
                  Text(
                    _showOriginalSummary
                        ? (game.summary ?? '')
                        : (game.displaySummary ?? ''),
                  ),
                ],
                const SizedBox(height: 24),
                logAsync.when(
                  data: (log) => _StatusAndLogSection(
                    gameId: widget.gameId,
                    log: log,
                    isUpdatingStatus: _isUpdatingStatus,
                    onMarkWantToPlay: _markWantToPlay,
                  ),
                  loading: () => const SizedBox(
                    height: 48,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (error, stackTrace) => const SizedBox.shrink(),
                ),
                if (game.similarGames.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('関連作品', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 150,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: game.similarGames.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final similar = game.similarGames[index];
                        return GestureDetector(
                          onTap: () => context.push('/games/${similar.id}'),
                          child: SizedBox(
                            width: 90,
                            child: Column(
                              children: [
                                CoverImage(
                                  url: similar.coverUrl,
                                  width: 90,
                                  height: 120,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  similar.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _IgdbAttribution(igdbUrl: game.igdbUrl),
              ],
            ),
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: 'ゲーム情報の取得に失敗しました',
          onRetry: () => ref.invalidate(gameDetailsProvider(widget.gameId)),
        ),
      ),
    );
  }

  String _companyLine(Game game) {
    final parts = <String>[];
    if (game.developers.isNotEmpty) parts.add('開発: ${game.developers.join(', ')}');
    if (game.publishers.isNotEmpty) parts.add('発売: ${game.publishers.join(', ')}');
    return parts.join(' / ');
  }
}

/// データ提供元（IGDB）の帰属表示と、当該ゲームのIGDBページへのリンク。
class _IgdbAttribution extends StatelessWidget {
  const _IgdbAttribution({required this.igdbUrl});

  final String? igdbUrl;

  Future<void> _open() async {
    final url = igdbUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        );
    if (igdbUrl == null) {
      return Text('ゲーム情報提供: IGDB', style: style);
    }
    return InkWell(
      onTap: _open,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('ゲーム情報提供: IGDBで見る', style: style),
          const SizedBox(width: 2),
          Icon(Icons.open_in_new, size: 14, color: style?.color),
        ],
      ),
    );
  }
}

class _StatusAndLogSection extends StatelessWidget {
  const _StatusAndLogSection({
    required this.gameId,
    required this.log,
    required this.isUpdatingStatus,
    required this.onMarkWantToPlay,
  });

  final int gameId;
  final GameLog? log;
  final bool isUpdatingStatus;
  final VoidCallback onMarkWantToPlay;

  @override
  Widget build(BuildContext context) {
    final isWantToPlay = log?.status == GameLogStatus.wantToPlay;
    final isPlayed = log?.status == GameLogStatus.played;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isUpdatingStatus ? null : onMarkWantToPlay,
                style: isWantToPlay
                    ? OutlinedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                      )
                    : null,
                icon: const Icon(Icons.bookmark_outline),
                label: const Text('遊びたい'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => context.push('/games/$gameId/log'),
                icon: Icon(isPlayed ? Icons.edit_outlined : Icons.videogame_asset),
                label: Text(isPlayed ? '記録を編集する' : '遊んだ'),
              ),
            ),
          ],
        ),
        if (isPlayed && log?.rating != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StarRating(rating: log!.rating!.toDouble(), size: 20),
                      if (log!.hasSpoiler) ...[
                        const SizedBox(width: 8),
                        const Chip(
                          label: Text('ネタバレあり'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                  if (log!.reviewText != null && log!.reviewText!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(log!.reviewText!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
