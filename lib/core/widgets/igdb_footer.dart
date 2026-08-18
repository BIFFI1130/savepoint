import 'package:flutter/material.dart';

/// ゲーム情報の提供元表示。IGDBの利用規約が求める帰属表示のため、ゲーム情報
/// （タイトル・カバー画像等）を表示する画面には必ず入れる。
class IgdbFooter extends StatelessWidget {
  const IgdbFooter({super.key, this.padding = const EdgeInsets.symmetric(vertical: 6)});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        'ゲーム情報提供: IGDB',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
      ),
    );
  }
}

/// [CustomScrollView] の末尾に置く、[IgdbFooter] のSliver版。
class IgdbFooterSliver extends StatelessWidget {
  const IgdbFooterSliver({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(child: IgdbFooter());
  }
}
