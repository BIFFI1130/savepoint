import 'package:flutter/material.dart';

/// トグル付きの設定項目1件分の表示。
///
/// [SwitchListTile] はタイトル・説明文の両方の高さに渡ってトグルが横に
/// 並ぶため、説明文の実際に使える幅がトグルの分だけ狭くなり、わずかな
/// 文字数でも不要な改行が起きやすい。ここではタイトルとトグルだけを
/// 同じ行に並べ、説明文はその下に全幅で表示する。
class ToggleOptionTile extends StatelessWidget {
  const ToggleOptionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.bodyLarge),
                ),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
