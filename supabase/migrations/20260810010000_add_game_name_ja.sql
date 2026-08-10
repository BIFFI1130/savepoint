-- ゲームタイトルの日本語表示用。概要(summary_ja)と同様、詳細取得時に翻訳してキャッシュする。
alter table public.games
  add column name_ja text;
