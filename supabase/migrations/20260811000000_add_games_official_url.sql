-- ゲーム詳細画面に表示する公式サイトURL。IGDBのwebsites(type=1=公式サイト)から
-- 取得し、詳細取得時にキャッシュする（summary_ja/name_jaと同様のパターン）。
alter table public.games
  add column official_url text;
