-- まとめ画面の「好きなジャンル」集計に使うため、gamesにジャンル名の配列を持たせる。
-- 既存行は次回のsearch/details/weekly_releases取得時に遅延的に埋まる。
alter table public.games
  add column genres text[] not null default '{}';
