import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/config/app_links.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../game_log/domain/game_log.dart';
import '../../domain/period_summary.dart';

/// まとめ画面のシェア用画像カード（9:16、360x640を3倍で書き出し）。
///
/// SNSに転載された画像にはリンクが付かないため、画像そのものにQRコードと
/// アプリ名を載せ、見た人がインストールまで辿れるようにしている。
class SummaryShareCard extends StatelessWidget {
  const SummaryShareCard({super.key, required this.summary});

  final PeriodSummary summary;

  static const _bgLight = Color(0xFF5A74FF);
  static const _bgDark = Color(0xFF2836C8);
  static const _maxCovers = 4;

  String get _headline => switch (summary.periodType) {
    SummaryPeriodType.year => '${summary.periodStart.year}年のゲームまとめ',
    SummaryPeriodType.month =>
      '${summary.periodStart.year}年${summary.periodStart.month}月のゲーム記録',
    SummaryPeriodType.week => '${summary.periodLabel}の記録',
    SummaryPeriodType.all => 'これまでのゲーム記録',
  };

  String get _bestLabel => summary.periodType == SummaryPeriodType.year
      ? '今年のベストゲーム'
      : 'ベストゲーム';

  /// 最も評価が高い作品（同点なら新しい記録）。評価付きが無い、または1本だけなら出さない。
  GameLogWithGame? get _bestGame {
    if (summary.playedCount < 2) return null;
    GameLogWithGame? best;
    for (final entry in summary.playedEntries) {
      final rating = entry.log.rating;
      if (rating == null) continue;
      final bestRating = best?.log.rating;
      if (bestRating == null ||
          rating > bestRating ||
          (rating == bestRating &&
              entry.log.createdAt.isAfter(best!.log.createdAt))) {
        best = entry;
      }
    }
    return best;
  }

  static String _formatRating(double rating) =>
      rating.toStringAsFixed(rating % 1 == 0 ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    final average = summary.averageRating;
    final best = _bestGame;
    final covers = summary.playedEntries
        .where((e) => e != best)
        .take(_maxCovers)
        .toList();
    final topGenres = summary.genreCounts.entries.take(4).toList();

    return Container(
      width: 360,
      height: 640,
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
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
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _headline,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 20),
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
          if (best != null) ...[
            const SizedBox(height: 20),
            _BestGameTile(
              label: _bestLabel,
              entry: best,
              ratingText: _formatRating(best.log.rating!),
            ),
          ],
          if (covers.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: Row(
                children: [
                  for (var i = 0; i < _maxCovers; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: i < covers.length
                          ? CoverImage(
                              url: covers[i].game.coverUrl,
                              width: double.infinity,
                              height: 100,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (topGenres.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in topGenres)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
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
          const Spacer(),
          const _InstallFooter(),
        ],
      ),
    );
  }
}

class _BestGameTile extends StatelessWidget {
  const _BestGameTile({
    required this.label,
    required this.entry,
    required this.ratingText,
  });

  final String label;
  final GameLogWithGame entry;
  final String ratingText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CoverImage(url: entry.game.coverUrl, width: 64, height: 88),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.game.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '★ $ratingText',
                  style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InstallFooter extends StatelessWidget {
  const _InstallFooter();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: QrImageView(
            data: AppLinks.landingUrl,
            size: 58,
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ゲーム人生を記録しよう',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'SavePoint（無料）',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              Text(
                AppLinks.landingUrl.replaceFirst('https://', ''),
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
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
