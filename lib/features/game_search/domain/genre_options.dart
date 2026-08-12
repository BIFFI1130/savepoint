import 'package:flutter/material.dart';

/// ジャンルの表示ラベル・IGDB上の正式なジャンル名・バッジ用のアイコンと色の対応表。
/// 検索画面のジャンルフィルタ・ゲーム詳細画面のジャンルバッジ・まとめ画面のジャンル別集計で
/// 共通して使う。IGDBのジャンル一覧から、日本のユーザーに馴染みのある分類のみを抜粋している。
const genreOptions = <(String label, String value, IconData icon, Color color)>[
  ('RPG', 'Role-playing (RPG)', Icons.castle, Color(0xFF6750A4)),
  ('アクション', "Hack and slash/Beat 'em up", Icons.bolt, Color(0xFFB3261E)),
  ('シューティング', 'Shooter', Icons.gps_fixed, Color(0xFF006C51)),
  ('アドベンチャー', 'Adventure', Icons.explore, Color(0xFF8B5000)),
  ('格闘', 'Fighting', Icons.sports_mma, Color(0xFF9C4146)),
  ('レース', 'Racing', Icons.directions_car_filled, Color(0xFF3A5B9B)),
  ('パズル', 'Puzzle', Icons.extension, Color(0xFF6E5A00)),
  ('ストラテジー', 'Strategy', Icons.psychology, Color(0xFF4A6148)),
  ('シミュレーション', 'Simulator', Icons.precision_manufacturing, Color(0xFF5C5F77)),
  ('スポーツ', 'Sport', Icons.sports_soccer, Color(0xFF1D6B5B)),
  ('プラットフォーマー', 'Platform', Icons.terrain, Color(0xFF7A5230)),
  ('インディー', 'Indie', Icons.auto_awesome, Color(0xFF884191)),
];

/// IGDBのジャンル名（英語）を日本語表示ラベルに変換する。対応表に無い場合は原文のまま返す。
String genreLabel(String igdbName) {
  for (final option in genreOptions) {
    if (option.$2 == igdbName) return option.$1;
  }
  return igdbName;
}
