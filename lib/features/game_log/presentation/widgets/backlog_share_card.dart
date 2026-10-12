import 'package:flutter/material.dart';

import '../../../../core/widgets/cover_image.dart';
import '../../../../core/widgets/share_install_footer.dart';
import '../../domain/backlog_estimate.dart';

/// 積みゲー消化シミュレーターのシェア用画像カード（9:16、360x640）。
class BacklogShareCard extends StatelessWidget {
  const BacklogShareCard({
    super.key,
    required this.estimate,
    required this.hoursPerWeek,
  });

  final BacklogEstimate estimate;
  final double hoursPerWeek;

  static const _bgLight = Color(0xFF5A74FF);
  static const _bgDark = Color(0xFF2836C8);

  @override
  Widget build(BuildContext context) {
    final span = describeWeeks(estimate.weeksToFinish(hoursPerWeek));
    final heavy = estimate.longest(4);

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
          const Text(
            '積みゲー消化シミュレーター',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            '週${_formatHours(hoursPerWeek)}時間遊ぶと、完走まで',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              span,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 52,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _Stat(value: '${estimate.totalGames}', label: '積みゲー（本）'),
              const SizedBox(width: 28),
              _Stat(value: estimate.totalHours.round().toString(), label: '合計（時間）'),
            ],
          ),
          if (heavy.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              '重量級の積みゲー',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: i < heavy.length
                          ? CoverImage(
                              url: heavy[i].entry.game.coverUrl,
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
          const Spacer(),
          const ShareInstallFooter(),
        ],
      ),
    );
  }

  static String _formatHours(double hours) =>
      hours.toStringAsFixed(hours % 1 == 0 ? 0 : 1);
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

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
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}
