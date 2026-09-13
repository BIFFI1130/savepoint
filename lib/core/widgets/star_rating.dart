import 'package:flutter/material.dart';

/// 5段階評価の入力・表示用ウィジェット。0.1刻みで細かく評価できる。
///
/// [onChanged] を渡すとタップ・ドラッグで評価を変更できる。渡さなければ読み取り専用表示になる。
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.rating,
    this.onChanged,
    this.size = 32,
  });

  final double rating;
  final ValueChanged<double>? onChanged;
  final double size;

  static const _starCount = 5;
  static const _spacing = 4.0;

  double _ratingFromLocalPosition(Offset position) {
    final unit = size + _spacing;
    final totalWidth = size * _starCount + _spacing * (_starCount - 1);
    final dx = position.dx.clamp(0.0, totalWidth);
    final starIndex = (dx / unit).floor().clamp(0, _starCount - 1);
    final withinStarX = dx - starIndex * unit;
    final fraction = (withinStarX / size).clamp(0.0, 1.0);
    final raw = starIndex + fraction;
    // 0.1刻みに丸める。
    final rounded = (raw * 10).round() / 10;
    return rounded.clamp(0.0, _starCount.toDouble());
  }

  void _handleGesture(Offset localPosition) {
    onChanged?.call(_ratingFromLocalPosition(localPosition));
  }

  @override
  Widget build(BuildContext context) {
    final stars = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _starCount; i++) ...[
          if (i > 0) const SizedBox(width: _spacing),
          _Star(fill: (rating - i).clamp(0.0, 1.0), size: size),
        ],
      ],
    );

    if (onChanged == null) return stars;

    return GestureDetector(
      onTapDown: (details) => _handleGesture(details.localPosition),
      onPanDown: (details) => _handleGesture(details.localPosition),
      onPanUpdate: (details) => _handleGesture(details.localPosition),
      child: stars,
    );
  }
}

/// 星1つ分の表示。[fill]（0.0〜1.0）の割合だけ塗りつぶした星を、
/// 縁取りだけの星の上に重ねて表示する。
class _Star extends StatelessWidget {
  const _Star({required this.fill, required this.size});

  final double fill;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Icon(Icons.star_border, size: size, color: Colors.amber),
          ClipRect(
            clipper: _FractionClipper(fill),
            child: Icon(Icons.star, size: size, color: Colors.amber),
          ),
        ],
      ),
    );
  }
}

class _FractionClipper extends CustomClipper<Rect> {
  const _FractionClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(covariant _FractionClipper oldClipper) =>
      oldClipper.fraction != fraction;
}
