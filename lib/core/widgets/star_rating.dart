import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

/// 5段階評価の入力・表示用ウィジェット。
///
/// [onChanged] を渡すとタップで評価を変更できる。渡さなければ読み取り専用表示になる。
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

  @override
  Widget build(BuildContext context) {
    return RatingBar.builder(
      initialRating: rating,
      minRating: 0,
      itemCount: 5,
      itemSize: size,
      allowHalfRating: false,
      ignoreGestures: onChanged == null,
      itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
      onRatingUpdate: (value) => onChanged?.call(value),
    );
  }
}
