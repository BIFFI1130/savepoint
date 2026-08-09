import 'package:flutter/material.dart';

/// アプリ全体のテーマ。
///
/// フォントは端末の日本語システムフォントに委ねている（iOS: ヒラギノ角ゴ, Android: Noto Sans CJK）。
/// 独自フォントを使いたくなったら ThemeData.textTheme に fontFamily を追加する。
class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3D5AFE)),
      appBarTheme: const AppBarTheme(centerTitle: true),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3D5AFE),
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(centerTitle: true),
    );
  }
}
