-- Twitch Developer Services Agreement は、Program Materials（IGDBデータ）の利用に際して
-- 帰属表示と、情報源への明確な導線（リンク）を求めている。
-- ゲームごとのIGDB上のページURLを保存し、アプリ側でリンクを表示できるようにする。

alter table public.games
  add column igdb_url text;
