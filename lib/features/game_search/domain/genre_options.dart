/// ジャンルの表示ラベルとIGDB上の正式なジャンル名の対応表。
/// 検索画面のジャンルフィルタ・まとめ画面のジャンル別集計で共通して使う。
const genreOptions = <(String label, String value)>[
  ('RPG', 'Role-playing (RPG)'),
  ('アクション', "Hack and slash/Beat 'em up"),
  ('シューティング', 'Shooter'),
  ('アドベンチャー', 'Adventure'),
  ('格闘', 'Fighting'),
  ('レース', 'Racing'),
  ('パズル', 'Puzzle'),
  ('ストラテジー', 'Strategy'),
  ('シミュレーション', 'Simulator'),
  ('スポーツ', 'Sport'),
  ('プラットフォーマー', 'Platform'),
  ('インディー', 'Indie'),
];

/// IGDBのジャンル名（英語）を日本語表示ラベルに変換する。対応表に無い場合は原文のまま返す。
String genreLabel(String igdbName) {
  for (final option in genreOptions) {
    if (option.$2 == igdbName) return option.$1;
  }
  return igdbName;
}
