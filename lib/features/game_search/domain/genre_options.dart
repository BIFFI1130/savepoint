import 'package:flutter/material.dart';

/// ジャンルの表示ラベル・IGDB上の正式なジャンル名・バッジ用のアイコンと色の対応表。
/// 検索画面のジャンルフィルタ・ゲーム詳細画面のジャンルバッジ・まとめ画面のジャンル別集計で
/// 共通して使う。https://www.igdb.com/genres に載っているIGDBの全ジャンル（23種、
/// 2026-08-14時点でigdb-proxy経由の/genresエンドポイントで確認済み）を網羅する。
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
  ('ポイント&クリック', 'Point-and-click', Icons.ads_click, Color(0xFF3D5A80)),
  ('音楽', 'Music', Icons.music_note, Color(0xFFB0468C)),
  ('リアルタイムストラテジー', 'Real Time Strategy (RTS)', Icons.military_tech, Color(0xFF2F5233)),
  ('ターン制ストラテジー', 'Turn-based strategy (TBS)', Icons.grid_view, Color(0xFF4E6E58)),
  ('タクティクス', 'Tactical', Icons.shield, Color(0xFF5B4B8A)),
  ('クイズ', 'Quiz/Trivia', Icons.quiz, Color(0xFFC77800)),
  ('ピンボール', 'Pinball', Icons.adjust, Color(0xFF7B3F61)),
  ('アーケード', 'Arcade', Icons.sports_esports, Color(0xFFAD1457)),
  ('ビジュアルノベル', 'Visual Novel', Icons.menu_book, Color(0xFF6A4C93)),
  ('カード・ボードゲーム', 'Card & Board Game', Icons.style, Color(0xFF546E7A)),
  ('MOBA', 'MOBA', Icons.groups, Color(0xFF00838F)),
];

/// IGDBのジャンル名（英語）を日本語表示ラベルに変換する。対応表に無い場合は原文のまま返す。
String genreLabel(String igdbName) {
  for (final option in genreOptions) {
    if (option.$2 == igdbName) return option.$1;
  }
  return igdbName;
}
