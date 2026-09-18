import 'package:flutter/material.dart';

/// テーマの表示ラベル・IGDB上の正式なテーマ名・バッジ用のアイコンと色の対応表。
/// ゲーム詳細画面のテーマバッジで使う。https://www.igdb.com/themes に載っている
/// IGDBの全テーマ（22種）を網羅する。
const themeOptions = <(String label, String value, IconData icon, Color color)>[
  ('アクション', 'Action', Icons.flash_on, Color(0xFFB3261E)),
  ('ファンタジー', 'Fantasy', Icons.auto_fix_high, Color(0xFF6750A4)),
  ('SF', 'Science fiction', Icons.rocket_launch, Color(0xFF00696D)),
  ('ホラー', 'Horror', Icons.nights_stay, Color(0xFF2B2930)),
  ('スリラー', 'Thriller', Icons.timer, Color(0xFF6E2A35)),
  ('サバイバル', 'Survival', Icons.forest, Color(0xFF3A5B22)),
  ('歴史', 'Historical', Icons.account_balance, Color(0xFF7A5230)),
  ('ステルス', 'Stealth', Icons.visibility_off, Color(0xFF44464F)),
  ('コメディ', 'Comedy', Icons.sentiment_very_satisfied, Color(0xFFC77800)),
  ('ビジネス', 'Business', Icons.business_center, Color(0xFF1D6B5B)),
  ('ドラマ', 'Drama', Icons.theater_comedy, Color(0xFF8B4A6B)),
  ('ノンフィクション', 'Non-fiction', Icons.menu_book, Color(0xFF546E7A)),
  ('サンドボックス', 'Sandbox', Icons.grid_view, Color(0xFF8B5000)),
  ('教育', 'Educational', Icons.school, Color(0xFF2F5233)),
  ('キッズ向け', 'Kids', Icons.child_care, Color(0xFFB0468C)),
  ('オープンワールド', 'Open world', Icons.public, Color(0xFF3A5B9B)),
  ('戦争', 'Warfare', Icons.military_tech, Color(0xFF5B4B33)),
  ('パーティー', 'Party', Icons.celebration, Color(0xFFAD1457)),
  ('4X', '4X (explore, expand, exploit, and exterminate)', Icons.travel_explore, Color(0xFF4A6148)),
  ('ミステリー', 'Mystery', Icons.search, Color(0xFF4E4478)),
  ('ロマンス', 'Romance', Icons.favorite_border, Color(0xFFC2185B)),
  ('エロティック', 'Erotic', Icons.favorite, Color(0xFF9C4146)),
];

/// IGDBのテーマ名（英語）を日本語表示ラベルに変換する。対応表に無い場合は原文のまま返す。
String themeLabel(String igdbName) {
  for (final option in themeOptions) {
    if (option.$2 == igdbName) return option.$1;
  }
  return igdbName;
}
