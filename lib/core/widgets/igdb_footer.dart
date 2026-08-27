import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _igdbHomeUrl = 'https://www.igdb.com';

Future<void> _openIgdbHome() async {
  final uri = Uri.tryParse(_igdbHomeUrl);
  if (uri != null) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// ゲーム情報の提供元表示。IGDBの利用規約が求める帰属表示のため、ゲーム情報
/// （タイトル・カバー画像等）を表示する画面には必ず入れる。「IGDB.com」部分は
/// IGDBのトップページへのリンクにする。
class IgdbFooter extends StatefulWidget {
  const IgdbFooter({super.key, this.padding = const EdgeInsets.symmetric(vertical: 6)});

  final EdgeInsetsGeometry padding;

  @override
  State<IgdbFooter> createState() => _IgdbFooterState();
}

class _IgdbFooterState extends State<IgdbFooter> {
  final _linkRecognizer = TapGestureRecognizer()..onTap = _openIgdbHome;

  @override
  void dispose() {
    _linkRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        );
    final linkStyle = style?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
    );
    return Padding(
      padding: widget.padding,
      child: Text.rich(
        TextSpan(
          style: style,
          children: [
            const TextSpan(text: 'Games metadata is powered by '),
            TextSpan(
              text: 'IGDB.com',
              style: linkStyle,
              recognizer: _linkRecognizer,
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// [CustomScrollView] の末尾に置く、[IgdbFooter] のSliver版。
class IgdbFooterSliver extends StatelessWidget {
  const IgdbFooterSliver({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(child: IgdbFooter());
  }
}
