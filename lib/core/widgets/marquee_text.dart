import 'package:flutter/material.dart';

/// 1行で表示するテキスト。折り返さず、指定された幅に収まらない場合のみ
/// 左右に往復スクロールするアニメーション（ビルボード表示）で全文を見せる。
/// 収まる場合は普通に静止表示する。
class MarqueeText extends StatefulWidget {
  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.pauseDuration = const Duration(seconds: 1, milliseconds: 200),
    this.pixelsPerSecond = 36,
  });

  final String text;
  final TextStyle? style;

  /// 端で折り返す前に静止する時間。
  final Duration pauseDuration;

  /// スクロール速度（1秒あたりのピクセル数）。
  final double pixelsPerSecond;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  final _scrollController = ScrollController();
  bool _loopStarted = false;

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _loopStarted = false;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeStartLoop(double overflow) {
    if (_loopStarted || overflow <= 0) return;
    _loopStarted = true;
    _runLoop(overflow);
  }

  Future<void> _runLoop(double overflow) async {
    final duration = Duration(
      milliseconds: (overflow / widget.pixelsPerSecond * 1000).round(),
    );
    while (mounted && _loopStarted) {
      await Future.delayed(widget.pauseDuration);
      if (!mounted || !_scrollController.hasClients) return;
      await _scrollController.animateTo(
        overflow,
        duration: duration,
        curve: Curves.linear,
      );
      if (!mounted || !_scrollController.hasClients) return;
      await Future.delayed(widget.pauseDuration);
      if (!mounted || !_scrollController.hasClients) return;
      await _scrollController.animateTo(
        0,
        duration: duration,
        curve: Curves.linear,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout();
        final overflow = painter.width - constraints.maxWidth;
        if (overflow > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _maybeStartLoop(overflow);
          });
        }
        return ClipRect(
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Text(
              widget.text,
              style: style,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        );
      },
    );
  }
}
