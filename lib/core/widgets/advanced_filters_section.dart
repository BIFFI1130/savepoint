import 'package:flutter/material.dart';

/// 一覧画面共通の「詳しい条件」折りたたみセクション（デフォルトで畳んだ状態）。
/// [includeAdult]・[onIncludeAdultChanged] で成人向け作品表示チェックボックスを提供し、
/// [children] で画面固有の追加フィルタ（開発元絞り込みなど）を並べられる。
class AdvancedFiltersSection extends StatefulWidget {
  const AdvancedFiltersSection({
    super.key,
    required this.includeAdult,
    required this.onIncludeAdultChanged,
    this.children = const [],
  });

  final bool includeAdult;
  final ValueChanged<bool> onIncludeAdultChanged;
  final List<Widget> children;

  @override
  State<AdvancedFiltersSection> createState() => _AdvancedFiltersSectionState();
}

class _AdvancedFiltersSectionState extends State<AdvancedFiltersSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            label: const Text('詳しい条件'),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _expanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...widget.children,
                    CheckboxListTile(
                      value: widget.includeAdult,
                      onChanged: (value) =>
                          widget.onIncludeAdultChanged(value ?? false),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      title: const Text('成人向け作品を表示する'),
                    ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
