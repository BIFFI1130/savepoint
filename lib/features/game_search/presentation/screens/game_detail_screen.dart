import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../../core/widgets/star_rating.dart';
import '../../../collections/presentation/widgets/collection_picker_sheet.dart';
import '../../../game_log/domain/game_log.dart';
import '../../../game_log/presentation/providers/log_providers.dart';
import '../../domain/game.dart';
import '../../domain/genre_options.dart';
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

  /// タップ中のジャンルバッジ（ラベル表示中のもの）。IGDBの正式なジャンル名で保持する。
  /// nullなら何も表示していない状態。
  String? _expandedGenre;

  Future<void> _markWantToPlay() async {
    setState(() => _isUpdatingStatus = true);
    try {
      await ref.read(logRepositoryProvider).markWantToPlay(widget.gameId);
      ref.invalidate(existingLogProvider(widget.gameId));
      ref.invalidate(myLogsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('更新に失敗しました')));
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _deleteLog(GameLog log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('記録を削除しますか？'),
        content: const Text('評価・レビューを含む記録が削除されます。この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isUpdatingStatus = true);
    try {
      await ref.read(logRepositoryProvider).deleteLog(log.id);
      ref.invalidate(existingLogProvider(widget.gameId));
      ref.invalidate(myLogsProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('記録を削除しました')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('削除に失敗しました')));
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
      body: Listener(
        // ジャンルバッジのラベル表示中に、画面上のどこか（別のバッジ含む）を
        // 操作したら閉じる。Listenerはジェスチャーアリーナに参加しないため、
        // 子のGestureDetector/InkWellのタップ判定を邪魔せずポインター押下だけ検知できる。
        onPointerDown: (_) {
          if (_expandedGenre != null) setState(() => _expandedGenre = null);
        },
        child: gameAsync.when(
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
                    child: CoverImage(
                      url: game.coverUrl,
                      width: 140,
                      height: 190,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    game.displayName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
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
                  if (game.genres.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final genre in game.genres)
                          _GenreBadge(
                            genre: genre,
                            selected: _expandedGenre == genre,
                            onTap: () => setState(() => _expandedGenre = genre),
                          ),
                      ],
                    ),
                  ],
                  if (game.displaySummary != null &&
                      game.displaySummary!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '概要',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (game.summaryJa != null && game.summary != null)
                          TextButton(
                            onPressed: () => setState(
                              () =>
                                  _showOriginalSummary = !_showOriginalSummary,
                            ),
                            child: Text(
                              _showOriginalSummary ? '日本語訳を表示' : '原文を表示',
                            ),
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
                      onDelete: log == null ? null : () => _deleteLog(log),
                    ),
                    loading: () => const SizedBox(
                      height: 48,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (error, stackTrace) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 12),
                  _StatsRow(gameId: widget.gameId),
                  if (game.similarGames.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      '関連作品',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 164,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: game.similarGames.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 12),
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
                                    similar.displayName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
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
                  _OfficialSiteLink(url: game.officialUrl),
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
      ),
    );
  }

  String _companyLine(Game game) {
    final parts = <String>[];
    if (game.developers.isNotEmpty) {
      parts.add('開発: ${game.developers.join(', ')}');
    }
    if (game.publishers.isNotEmpty) {
      parts.add('発売: ${game.publishers.join(', ')}');
    }
    return parts.join(' / ');
  }
}

/// ジャンルを表す小さな正方形バッジ。発売年チップと高さを揃えている。
/// タップするとラベルが横に展開表示され、他の操作（別バッジのタップや画面上の
/// どこかへのタップなど）を行うと閉じる（親のGameDetailScreenがLIstenerで管理）。
class _GenreBadge extends StatelessWidget {
  const _GenreBadge({
    required this.genre,
    required this.selected,
    required this.onTap,
  });

  /// IGDBの正式なジャンル名（英語）。
  final String genre;

  /// ラベルを展開表示中かどうか。
  final bool selected;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final option = genreOptions
        .cast<(String, String, IconData, Color)?>()
        .firstWhere((o) => o!.$2 == genre, orElse: () => null);
    final label = option?.$1 ?? genre;
    final icon = option?.$3 ?? Icons.sports_esports;
    final color = option?.$4 ?? Theme.of(context).colorScheme.outline;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 32,
          padding: EdgeInsets.symmetric(horizontal: selected ? 8 : 7),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              if (selected) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 「遊んだ／遊びたい」の人数（全ユーザー集計）を表示する。
class _StatsRow extends ConsumerWidget {
  const _StatsRow({required this.gameId});

  final int gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(gameStatsProvider(gameId));

    return statsAsync.when(
      data: (stats) {
        if (stats == null ||
            (stats.playedCount == 0 && stats.wantToPlayCount == 0)) {
          return const SizedBox.shrink();
        }
        final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        );
        return Wrap(
          spacing: 16,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (stats.ratingCount > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    '${stats.avgRating!.toStringAsFixed(1)}（${stats.ratingCount}件）',
                    style: style,
                  ),
                ],
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.videogame_asset_outlined,
                  size: 16,
                  color: style?.color,
                ),
                const SizedBox(width: 4),
                Text('遊んだ ${stats.playedCount}人', style: style),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bookmark_outline, size: 16, color: style?.color),
                const SizedBox(width: 4),
                Text('遊びたい ${stats.wantToPlayCount}人', style: style),
              ],
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, _) => const SizedBox.shrink(),
    );
  }
}

/// 公式サイトへのリンク（あれば表示）。複数の公式サイトがある場合は
/// 日本語ページらしいものをigdb-proxy側で優先的に選んでいる。
class _OfficialSiteLink extends StatelessWidget {
  const _OfficialSiteLink({required this.url});

  final String? url;

  Future<void> _open() async {
    final value = url;
    if (value == null) return;
    final uri = Uri.tryParse(value);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (url == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: _open,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.public,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              '公式サイトを見る',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.open_in_new,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
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
    required this.onDelete,
  });

  final int gameId;
  final GameLog? log;
  final bool isUpdatingStatus;
  final VoidCallback onMarkWantToPlay;
  final VoidCallback? onDelete;

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
              child: isWantToPlay
                  ? FilledButton.icon(
                      onPressed: isUpdatingStatus ? null : onMarkWantToPlay,
                      icon: const Icon(Icons.bookmark),
                      label: const Text('遊びたい登録済み'),
                    )
                  : OutlinedButton.icon(
                      onPressed: isUpdatingStatus ? null : onMarkWantToPlay,
                      icon: const Icon(Icons.bookmark_outline),
                      label: const Text('遊びたい'),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => context.push('/games/$gameId/log'),
                icon: Icon(
                  isPlayed ? Icons.edit_outlined : Icons.videogame_asset,
                ),
                label: Text(isPlayed ? '記録を編集する' : '遊んだ'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => CollectionPickerSheet.show(context, gameId),
          icon: const Icon(Icons.playlist_add),
          label: const Text('コレクションに追加'),
        ),
        if (onDelete != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: isUpdatingStatus ? null : onDelete,
            icon: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            label: Text(
              '記録を削除する',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
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
                  if (log!.reviewText != null &&
                      log!.reviewText!.isNotEmpty) ...[
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
