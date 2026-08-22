import 'package:flutter/material.dart';

/// アプリ全体のテーマ。
///
/// フォントは端末の日本語システムフォントに委ねている（iOS: ヒラギノ角ゴ, Android: Noto Sans CJK）。
/// 独自フォントを使いたくなったら ThemeData.textTheme に fontFamily を追加する。
class AppTheme {
  /// アプリアイコン（セーブポイントの旗）に合わせた配色。
  /// 珊瑚色の旗をシード、ミントの地形を副色、ポールのタン色を第三色にしている。
  static const _iconCoral = Color(0xFFFF6B81);
  static const _iconMint = Color(0xFF4FB98C);
  static const _iconTan = Color(0xFFE3B873);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _iconCoral).copyWith(
        secondary: _iconMint,
        tertiary: _iconTan,
      ),
      appBarTheme: const AppBarTheme(centerTitle: true),
    );
  }

  /// 旧配色（濃い青紫のシード）はダークモード専用として維持する。
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
