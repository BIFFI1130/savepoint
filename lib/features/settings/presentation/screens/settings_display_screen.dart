import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_mode_service.dart';

/// 設定 → 表示。ダークモードの手動切り替え。
class SettingsDisplayScreen extends ConsumerWidget {
  const SettingsDisplayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('表示')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('テーマ', style: Theme.of(context).textTheme.titleMedium),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('端末に合わせる'),
                ),
                ButtonSegment(value: ThemeMode.light, label: Text('ライト')),
                ButtonSegment(value: ThemeMode.dark, label: Text('ダーク')),
              ],
              selected: {themeMode},
              onSelectionChanged: (selection) => ref
                  .read(themeModeProvider.notifier)
                  .setThemeMode(selection.first),
            ),
          ),
        ],
      ),
    );
  }
}
