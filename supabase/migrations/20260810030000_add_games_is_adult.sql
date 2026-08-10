-- 検索・ホーム・トレンド・マイログの一覧から、デフォルトで成人向け作品を除外するためのフラグ。
-- IGDBのthemes（テーマ）に "Erotic" が含まれるかどうかをigdb-proxy側で判定してキャッシュする。
alter table public.games
  add column is_adult boolean not null default false;
