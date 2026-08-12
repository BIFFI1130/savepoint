import 'package:flutter/material.dart';

import '../../features/game_search/domain/genre_options.dart';

/// ジャンルの選択肢を正方形バッジで並べるセレクタ。複数選択可能（選択されたうちどれか
/// 1つでも当てはまればOR条件で一覧に含める、という使い方を想定）。
/// 検索画面・ホーム画面（各セクションの一覧画面）で共通して使う。
class GenreBadgeSelector extends StatelessWidget {
  const GenreBadgeSelector({
    super.key,
    required this.selectedGenres,
    required this.onToggle,
  });

  final Set<String> selectedGenres;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in genreOptions)
          _GenreBadge(
            label: option.$1,
            icon: option.$3,
            color: option.$4,
            selected: selectedGenres.contains(option.$2),
            onTap: () => onToggle(option.$2),
          ),
      ],
    );
  }
}

/// ジャンルの選択肢を表す正方形のバッジ。アイコンを中央に、ラベルを右下に配置する。
class _GenreBadge extends StatelessWidget {
  const _GenreBadge({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: selected
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 4),
                const Icon(Icons.check_circle, color: Colors.white, size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
