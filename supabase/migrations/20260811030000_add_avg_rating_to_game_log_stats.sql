-- game_log_stats に全ユーザーの評価平均(avg_rating)と評価件数(rating_count)を追加する。
-- 「遊んだ」かつ評価が入力されているログのみを対象とする。
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
  count(gl.rating) filter (where gl.status = 'played' and gl.rating is not null) as rating_count
from public.game_logs gl
join public.games g on g.id = gl.game_id
group by g.id, g.name, g.cover_url, g.name_ja, g.is_adult, g.is_japanese_developer;
