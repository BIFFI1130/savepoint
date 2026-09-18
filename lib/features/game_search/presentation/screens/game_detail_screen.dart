import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../../core/ads/banner_ad_widget.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/notifications/release_reminder_service.dart';
import '../../../../core/subscription/subscription_providers.dart';
import '../../../../core/utils/release_countdown.dart';
import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/avatar_image.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../../core/widgets/igdb_footer.dart';
import '../../../../core/widgets/star_rating.dart';
import '../../../collections/presentation/widgets/collection_picker_sheet.dart';
import '../../../game_log/domain/game_log.dart';
import '../../../game_log/presentation/providers/like_providers.dart';
import '../../../game_log/presentation/providers/log_providers.dart';
import '../../../social/domain/follow_feed_entry.dart';
import '../../../social/presentation/providers/social_providers.dart';
import '../../../social/presentation/widgets/report_user_dialog.dart';
import '../../domain/game.dart';
import '../../domain/genre_options.dart';
import '../providers/game_search_providers.dart';

/// 対応言語テーブルでの表示名（IGDBの英語表記→日本語）。
/// 一覧に無い言語はIGDBの英語表記のまま表示する。
const _languageDisplayNames = {
  'Japanese': '日本語',
  'English': '英語',
  'French': 'フランス語',
  'Italian': 'イタリア語',
  'German': 'ドイツ語',
  'Spanish (Spain)': 'スペイン語',
  'Spanish (Latin America)': 'スペイン語（中南米）',
  'Portuguese (Brazil)': 'ポルトガル語（ブラジル）',
  'Portuguese (Portugal)': 'ポルトガル語',
  'Russian': 'ロシア語',
  'Polish': 'ポーランド語',
  'Dutch': 'オランダ語',
  'Danish': 'デンマーク語',
  'Swedish': 'スウェーデン語',
  'Norwegian': 'ノルウェー語',
  'Finnish': 'フィンランド語',
  'Turkish': 'トルコ語',
  'Arabic': 'アラビア語',
  'Thai': 'タイ語',
  'Vietnamese': 'ベトナム語',
  'Korean': '韓国語',
  'Chinese (Simplified)': '中国語（簡体字）',
  'Chinese (Traditional)': '中国語（繁体字）',
  'Czech': 'チェコ語',
  'Hungarian': 'ハンガリー語',
  'Ukrainian': 'ウクライナ語',
  'Greek': 'ギリシャ語',
  'Romanian': 'ルーマニア語',
  'Indonesian': 'インドネシア語',
};

String _languageLabel(String language) =>
    _languageDisplayNames[language] ?? language;

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

  /// 「遊びたい」ボタンのトグル動作。既に「遊びたい」登録済みなら記録ごと削除して解除する
  /// （遊びたい記録は評価・レビューを持たないため、解除＝削除で問題ない）。
  /// それ以外（未登録・遊んだ済み）の場合は「遊びたい」として登録する。
  Future<void> _toggleWantToPlay(GameLog? log, Game game) async {
    setState(() => _isUpdatingStatus = true);
    try {
      if (log != null && log.status == GameLogStatus.wantToPlay) {
        await ref.read(logRepositoryProvider).deleteLog(log.id);
        await ref.read(appAnalyticsProvider).logRecordDeleted();
        await ref.read(releaseReminderServiceProvider).cancelForGame(widget.gameId);
      } else {
        await ref.read(logRepositoryProvider).markWantToPlay(widget.gameId);
        await ref.read(appAnalyticsProvider).logRecordCreated(
              status: 'want_to_play',
              hasRating: false,
              hasReview: false,
            );
        final releaseDate = game.firstReleaseDate;
        if (releaseDate != null) {
          await ref.read(releaseReminderServiceProvider).scheduleForGame(
                gameId: widget.gameId,
                title: game.displayName,
                releaseDate: releaseDate,
              );
        }
      }
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

  /// 「プレイ中にする」ボタンのトグル動作。既に「プレイ中」登録済みなら記録ごと削除して解除する
  /// （プレイ中の記録は評価・レビューを持たないため、解除＝削除で問題ない）。
  /// それ以外（未登録・遊びたい登録済み・遊んだ済み）の場合は「プレイ中」として登録する。
  Future<void> _togglePlaying(GameLog? log) async {
    setState(() => _isUpdatingStatus = true);
    try {
      if (log != null && log.status == GameLogStatus.playing) {
        await ref.read(logRepositoryProvider).deleteLog(log.id);
        await ref.read(appAnalyticsProvider).logRecordDeleted();
      } else {
        await ref.read(logRepositoryProvider).markPlaying(widget.gameId);
        await ref.read(appAnalyticsProvider).logRecordCreated(
              status: 'playing',
              hasRating: false,
              hasReview: false,
            );
      }
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
      await ref.read(appAnalyticsProvider).logRecordDeleted();
      if (log.status == GameLogStatus.wantToPlay) {
        await ref.read(releaseReminderServiceProvider).cancelForGame(widget.gameId);
      }
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

  Future<void> _shareGame(Game game) async {
    final buffer = StringBuffer('SavePointで「${game.displayName}」を記録しました。\n');
    if (game.igdbUrl != null) {
      buffer.write(game.igdbUrl);
    }
    await SharePlus.instance.share(ShareParams(text: buffer.toString()));
    await ref.read(appAnalyticsProvider).logShare(contentType: 'game');
  }

  @override
  Widget build(BuildContext context) {
    final gameAsync = ref.watch(gameDetailsProvider(widget.gameId));
    final logAsync = ref.watch(existingLogProvider(widget.gameId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('ゲーム詳細'),
        // ホーム画面ウィジェットのタップ等、遷移スタックを持たずにこの画面へ
        // 直接遷移してきた場合（context.canPop()がfalse）は戻る先が無いため、
        // マイログのタブへ移動するボタンを代わりに出す。
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: '戻る',
                onPressed: () => context.pop(),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'マイログに戻る',
                onPressed: () => context.go('/home', extra: 3),
              ),
      ),
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
            final countdownLabel = releaseCountdownLabel(game.firstReleaseDate);
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          game.displayName,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_outlined),
                        tooltip: '共有',
                        onPressed: () => _shareGame(game),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (game.developers.isNotEmpty || game.publishers.isNotEmpty)
                    Text(
                      _companyLine(game),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  if (game.firstReleaseDate != null)
                    Text(
                      _formatReleaseDate(game.firstReleaseDate!),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
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
                  const SizedBox(height: 4),
                  _OfficialSiteLink(url: game.officialUrl),
                  _IgdbAttribution(igdbUrl: game.igdbUrl),
                  const SizedBox(height: 8),
                  _StatsRow(gameId: widget.gameId),
                  if (countdownLabel != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          countdownLabel,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
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
                  if (game.trailerYoutubeId != null) ...[
                    const SizedBox(height: 16),
                    Text('トレーラー', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _TrailerPlayer(youtubeId: game.trailerYoutubeId!),
                  ],
                  if (game.screenshotUrls.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'スクリーンショット',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: game.screenshotUrls.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) => CoverImage(
                          url: game.screenshotUrls[index],
                          width: 213,
                          height: 120,
                        ),
                      ),
                    ),
                  ],
                  if (game.hasTimeToBeat) ...[
                    const SizedBox(height: 16),
                    Text('平均クリア時間', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _TimeToBeatRow(game: game),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (game.ageRatingOrganization != null)
                        Chip(
                          label: Text(
                            '${game.ageRatingOrganization} ${game.ageRatingValue}',
                          ),
                        ),
                      for (final platform in game.platforms)
                        Chip(label: Text(platform)),
                    ],
                  ),
                  if (game.languageSupports.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('対応言語', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _LanguageSupportTable(languages: game.languageSupports),
                  ],
                  if (!ref.watch(isAdFreeProvider)) ...[
                    const SizedBox(height: 16),
                    const BannerAdWidget(),
                  ],
                  const SizedBox(height: 24),
                  logAsync.when(
                    data: (log) => _StatusAndLogSection(
                      gameId: widget.gameId,
                      log: log,
                      releaseDate: game.firstReleaseDate,
                      isUpdatingStatus: _isUpdatingStatus,
                      onMarkWantToPlay: () => _toggleWantToPlay(log, game),
                      onMarkPlaying: () => _togglePlaying(log),
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
                  if (game.seriesGames.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'シリーズ作品',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _GameCoverRow(games: game.seriesGames),
                  ],
                  if (game.similarGames.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      '関連作品',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _GameCoverRow(games: game.similarGames),
                  ],
                  _PublicReviewsSection(gameId: widget.gameId),
                  const IgdbFooter(),
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

  String _formatReleaseDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }
}

/// IGDBの平均クリア時間（Time To Beat）を「急ぎ／通常／完全」の3列で表示する。
/// データが無い列は「-」を表示し、3列のレイアウト自体は常に揃える。
class _TimeToBeatRow extends StatelessWidget {
  const _TimeToBeatRow({required this.game});

  final Game game;

  static String _formatHours(int? seconds) {
    if (seconds == null) return '-';
    final hours = (seconds / 3600).round();
    return '${hours}H';
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        );
    final valueStyle = Theme.of(context).textTheme.titleMedium;
    Widget column(String label, int? seconds) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label, style: labelStyle),
            const SizedBox(height: 4),
            Text(_formatHours(seconds), style: valueStyle),
          ],
        ),
      );
    }

    return Row(
      children: [
        column('急ぎ', game.timeToBeatHastilySeconds),
        column('通常', game.timeToBeatNormallySeconds),
        column('完全', game.timeToBeatCompletelySeconds),
      ],
    );
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
            (stats.playedCount == 0 &&
                stats.wantToPlayCount == 0 &&
                stats.favoriteCount == 0)) {
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
            if (stats.favoriteCount > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite, size: 16, color: style?.color),
                  const SizedBox(width: 4),
                  Text('推しゲー ${stats.favoriteCount}人', style: style),
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

/// 対応言語一覧を「言語×音声/字幕/UI」の表形式で表示する（試験実装）。
/// 日本語・英語のみ最初から表示し、それ以外は折りたたんでおく
/// （対応言語が多い作品だと表が縦に長くなりすぎるため）。
class _LanguageSupportTable extends StatefulWidget {
  const _LanguageSupportTable({required this.languages});

  final List<LanguageSupport> languages;

  @override
  State<_LanguageSupportTable> createState() => _LanguageSupportTableState();
}

class _LanguageSupportTableState extends State<_LanguageSupportTable> {
  static const _alwaysShownLanguages = {'Japanese', 'English'};

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.languages
        .where((l) => _alwaysShownLanguages.contains(l.language))
        .toList();
    final others = widget.languages
        .where((l) => !_alwaysShownLanguages.contains(l.language))
        .toList();
    final visibleRows = [...primary, if (_expanded) ...others];
    final borderColor = Theme.of(context).colorScheme.outlineVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Table(
          border: TableBorder.all(color: borderColor),
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              children: const [
                _LanguageTableCell(text: ''),
                _LanguageTableCell(text: '音声'),
                _LanguageTableCell(text: '字幕'),
                _LanguageTableCell(text: 'UI'),
              ],
            ),
            for (final entry in visibleRows)
              TableRow(
                children: [
                  _LanguageTableCell(
                    text: _languageLabel(entry.language),
                    alignStart: true,
                  ),
                  _LanguageTableCell(text: entry.audio ? '○' : ''),
                  _LanguageTableCell(text: entry.subtitles ? '○' : ''),
                  _LanguageTableCell(text: entry.interfaceSupport ? '○' : ''),
                ],
              ),
          ],
        ),
        if (others.isNotEmpty)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? '折りたたむ' : 'その他の対応言語を表示（${others.length}）',
            ),
          ),
      ],
    );
  }
}

class _LanguageTableCell extends StatelessWidget {
  const _LanguageTableCell({required this.text, this.alignStart = false});

  final String text;
  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Text(
        text,
        textAlign: alignStart ? TextAlign.start : TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _GameCoverRow extends StatelessWidget {
  const _GameCoverRow({required this.games});

  final List<SimilarGame> games;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 164,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: games.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final game = games[index];
          return GestureDetector(
            onTap: () => context.push('/games/${game.id}'),
            child: SizedBox(
              width: 90,
              child: Column(
                children: [
                  CoverImage(url: game.coverUrl, width: 90, height: 120),
                  const SizedBox(height: 4),
                  Text(
                    game.displayName,
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
    );
  }
}

/// トレーラー動画（YouTube）のアプリ内埋め込み再生（試験実装）。
class _TrailerPlayer extends StatefulWidget {
  const _TrailerPlayer({required this.youtubeId});

  final String youtubeId;

  static final _youtubeIdPattern = RegExp(r'^[A-Za-z0-9_-]+$');

  @override
  State<_TrailerPlayer> createState() => _TrailerPlayerState();
}

class _TrailerPlayerState extends State<_TrailerPlayer> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    // youtubeIdはIGDB由来（igdb-proxy経由で取得・キャッシュ）だが、動画IDとして
    // 想定外の文字が混ざっていないか一応検証してからコントローラーに渡す。
    if (_TrailerPlayer._youtubeIdPattern.hasMatch(widget.youtubeId)) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: widget.youtubeId,
        autoPlay: false,
        params: const YoutubePlayerParams(showFullscreenButton: true),
      );
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: YoutubePlayer(controller: controller, aspectRatio: 16 / 9),
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
    // urlはIGDB由来（igdb-proxy経由で取得・キャッシュ）で、ユーザーが直接編集できる
    // フィールドではないが、多層防御としてhttp/https以外のスキームは開かない。
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
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
    // 同上（_OfficialSiteLink._open参照）。IGDB由来のURLでもスキームを検証する。
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
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
    required this.releaseDate,
    required this.isUpdatingStatus,
    required this.onMarkWantToPlay,
    required this.onMarkPlaying,
    required this.onDelete,
  });

  final int gameId;
  final GameLog? log;
  final DateTime? releaseDate;
  final bool isUpdatingStatus;
  final VoidCallback onMarkWantToPlay;
  final VoidCallback onMarkPlaying;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isWantToPlay = log?.status == GameLogStatus.wantToPlay;
    final isPlaying = log?.status == GameLogStatus.playing;
    final isPlayed = log?.status == GameLogStatus.played;
    final isUnreleased = releaseDate != null && releaseDate!.isAfter(DateTime.now());

    // 3つを1つのRowに横並びさせるため、アイコン・文字を小さめにしてラベルが
    // 折り返さず1行に収まるようにしている。
    const statusIconSize = 14.0;
    const statusButtonPadding = EdgeInsets.zero;
    const statusLabelStyle = TextStyle(
      fontSize: 18,
      overflow: TextOverflow.ellipsis,
    );
    final filledStatusStyle = FilledButton.styleFrom(
      padding: statusButtonPadding,
      textStyle: statusLabelStyle,
    );
    final outlinedStatusStyle = OutlinedButton.styleFrom(
      padding: statusButtonPadding,
      textStyle: statusLabelStyle,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: isWantToPlay
                  ? FilledButton.icon(
                      style: filledStatusStyle,
                      onPressed: isUpdatingStatus ? null : onMarkWantToPlay,
                      icon: const Icon(Icons.bookmark, size: statusIconSize),
                      label: const Text('遊びたい', maxLines: 1),
                    )
                  : OutlinedButton.icon(
                      style: outlinedStatusStyle,
                      onPressed: isUpdatingStatus ? null : onMarkWantToPlay,
                      icon: const Icon(Icons.bookmark_outline, size: statusIconSize),
                      label: const Text('遊びたい', maxLines: 1),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: isPlaying
                  ? FilledButton.icon(
                      style: filledStatusStyle,
                      onPressed: isUpdatingStatus ? null : onMarkPlaying,
                      icon: const Icon(Icons.sports_esports, size: statusIconSize),
                      label: const Text('プレイ中', maxLines: 1),
                    )
                  : OutlinedButton.icon(
                      style: outlinedStatusStyle,
                      onPressed: isUpdatingStatus ? null : onMarkPlaying,
                      icon: const Icon(Icons.sports_esports_outlined, size: statusIconSize),
                      label: const Text('プレイ中', maxLines: 1),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: isPlayed
                  ? FilledButton.icon(
                      style: filledStatusStyle,
                      onPressed: () => context.push('/games/$gameId/log'),
                      icon: const Icon(Icons.edit_outlined, size: statusIconSize),
                      label: const Text('記録を編集', maxLines: 1),
                    )
                  : OutlinedButton.icon(
                      style: outlinedStatusStyle,
                      onPressed: isUnreleased
                          ? null
                          : () => context.push('/games/$gameId/log'),
                      icon: const Icon(Icons.videogame_asset, size: statusIconSize),
                      label: Text(isUnreleased ? '発売前' : '遊んだ', maxLines: 1),
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

/// 「みんなのレビュー」。フォロー関係を問わず、公開設定の全ユーザーのレビューを
/// ゲーム単位で表示する。投稿者の身元（ユーザー名・アバター）は、投稿者本人が
/// プロフィール設定で表示を許可している場合のみ表示される（デフォルトは匿名）。
class _PublicReviewsSection extends ConsumerWidget {
  const _PublicReviewsSection({required this.gameId});

  final int gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text('みんなのレビュー', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ref.watch(gamePublicReviewsProvider(gameId)).when(
              data: (reviews) {
                if (reviews.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('まだレビューがありません'),
                  );
                }
                Future.microtask(
                  () => ref
                      .read(likesProvider.notifier)
                      .ensureLoaded(reviews.map((e) => e.logId)),
                );
                return Column(
                  children: [
                    for (var i = 0; i < reviews.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _PublicReviewTile(entry: reviews[i]),
                    ],
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (error, _) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('レビューの取得に失敗しました'),
              ),
            ),
      ],
    );
  }
}

/// 評価・レビューカード。投稿者が身元表示を許可している場合はユーザー名・アバターを
/// 表示し、タップでプロフィールへ遷移できる（フォローのきっかけ）。許可していない
/// 場合（デフォルト）はentry.username等がnullで届くため、匿名表示になる。
class _PublicReviewTile extends ConsumerStatefulWidget {
  const _PublicReviewTile({required this.entry});

  final FollowFeedEntry entry;

  @override
  ConsumerState<_PublicReviewTile> createState() => _PublicReviewTileState();
}

class _PublicReviewTileState extends ConsumerState<_PublicReviewTile> {
  @override
  void initState() {
    super.initState();
    unawaited(
      ref
          .read(viewAnalyticsRepositoryProvider)
          .recordReviewView(widget.entry.logId, widget.entry.userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final hasReviewText = entry.reviewText != null && entry.reviewText!.isNotEmpty;
    final showsIdentity = entry.displayName != null;
    final outline = Theme.of(context).colorScheme.outline;
    final likes = ref.watch(likesProvider);
    final isLiked = likes.isLikedByMe(entry.logId);
    final likeCount = likes.countFor(entry.logId);

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showsIdentity)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  AvatarImage(url: entry.avatarUrl, radius: 12),
                  const SizedBox(width: 6),
                  Text(
                    entry.userLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
            ),
          if (entry.rating != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StarRating(rating: entry.rating!, size: 16),
                if (entry.hasSpoiler) ...[
                  const SizedBox(width: 6),
                  const Chip(
                    label: Text('ネタバレあり'),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ],
            ),
          if (hasReviewText)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                entry.reviewText!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () =>
                      ref.read(likesProvider.notifier).toggle(entry.logId),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: isLiked
                              ? Theme.of(context).colorScheme.error
                              : outline,
                        ),
                        if (likeCount > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '$likeCount',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: outline),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // 匿名表示中（身元非表示）でも投稿者のuser_idは保持されているため、
                // 表示名を出さずに通報だけは可能にする。
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () =>
                      showReportUserDialog(context, ref, entry.userId),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                    child: Icon(
                      Icons.flag_outlined,
                      size: 16,
                      color: outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!showsIdentity) return content;
    return InkWell(
      onTap: () => context.push('/users/${entry.userId}'),
      child: content,
    );
  }
}
