-- game_log_stats に g.genres を追加する（トレンド画面のジャンル絞り込み用）。
-- CREATE OR REPLACE VIEWは列の末尾追加のみ許可されるため、既存の列順は変えない。
create or replace view public.game_log_stats as
select
  g.id as game_id,
  g.name,
  g.cover_url,
  count(*) filter (where gl.status = 'played') as played_count,
  count(*) filter (where gl.status = 'want_to_play') as want_to_play_count,
  g.name_ja,
  g.is_adult,
  g.is_japanese_developer,
  avg(gl.rating) filter (where gl.status = 'played' and gl.rating is not null) as avg_rating,
  count(gl.rating) filter (where gl.status = 'played' and gl.rating is not null) as rating_count,
  g.genres
from public.game_logs gl
join public.games g on g.id = gl.game_id
group by g.id, g.name, g.cover_url, g.name_ja, g.is_adult, g.is_japanese_developer, g.genres;
