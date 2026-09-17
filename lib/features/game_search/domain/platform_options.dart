/// 対応ハードフィルタの選択肢（表示ラベル, IGDB検索に渡す値）。
/// 検索画面・ホーム画面（今週発売のゲーム）で共通して使う。
/// この[value]はライブ経路（igdb-proxy、部分一致検索）にそのまま渡される値であり、
/// `games.platforms`（IGDBの正式名称、例: "Nintendo Switch"）の部分文字列に
/// なるよう意図的に短く定義している。完全一致が必要な場面（ローカルキャッシュの
/// RPC・クライアント側フィルタ）では[expandPlatformFilterValues]で正式名称に
/// 展開してから使うこと。
const platformOptions = <(String label, String value)>[
  ('Switch', 'Switch'),
  ('PS5', 'PlayStation 5'),
  ('PS4', 'PlayStation 4'),
  ('Xbox', 'Xbox'),
  ('PC', 'Windows'),
  ('iOS', 'iOS'),
  ('Android', 'Android'),
];

/// [platformOptions]の[value]（部分一致用の短い値）を、`games.platforms`に
/// 実際に格納されているIGDBの正式名称に展開するマップ。ここに現れない値
/// （PlayStation 4/5・iOS・Androidなど、IGDB側の名称と完全一致するもの）は
/// 変換不要のためエントリを持たない。
///
/// 例えば「Switch」は IGDB上で "Nintendo Switch"・"Nintendo Switch 2" の
/// 2つの正式名称に分かれており、「Xbox」も世代ごとに "Xbox"・"Xbox 360"・
/// "Xbox One"・"Xbox Series X|S" の4つに分かれている（2026-09時点でSupabase
/// dev環境の`igdb_platforms`テーブルを直接確認して洗い出した値）。
const _platformFilterValueExpansions = <String, List<String>>{
  'Switch': ['Nintendo Switch', 'Nintendo Switch 2'],
  'Xbox': ['Xbox', 'Xbox 360', 'Xbox One', 'Xbox Series X|S'],
  'Windows': ['PC (Microsoft Windows)'],
};

/// `games.platforms`との完全一致比較（ローカルキャッシュのRPC呼び出し・
/// クライアント側の`List.contains`によるフィルタ）に使う前に、[selected]
/// （[platformOptions]の[value]の集合）をIGDBの正式名称の集合へ展開する。
/// 対応表にない値（既に正式名称と一致するもの）はそのまま含める。
Set<String> expandPlatformFilterValues(Set<String> selected) {
  if (selected.isEmpty) return selected;
  final expanded = <String>{};
  for (final value in selected) {
    expanded.addAll(_platformFilterValueExpansions[value] ?? [value]);
  }
  return expanded;
}
