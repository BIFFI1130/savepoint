-- 「遊んだ」「遊びたい」の2値だった記録ステータスに「プレイ中」を追加する。
-- 評価（rating）は既存migration（20260812000000）で「遊んだ」でも任意になっているため、
-- 今回はステータスの許容値を増やすのみで、rating関連の制約には触れない。

alter table public.game_logs drop constraint game_logs_status_check;
alter table public.game_logs
  add constraint game_logs_status_check
  check (status in ('played', 'want_to_play', 'playing'));

-- game_log_stats に playing_count（「プレイ中」人数、全ユーザー集計）を追加する。
-- 列は末尾に追加する（create or replaceでは列の位置的な入れ替え・改名ができないため、
-- 既存列はそのままの位置を保ったまま新規列だけ末尾に足す）。
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
  g.genres,
  coalesce(fg.favorite_count, 0) as favorite_count,
  count(*) filter (where gl.status = 'playing') as playing_count
from public.game_logs gl
join public.games g on g.id = gl.game_id
left join (
  select game_id, count(*) as favorite_count
  from public.favorite_games
  group by game_id
) fg on fg.game_id = g.id
group by
  g.id, g.name, g.cover_url, g.name_ja, g.is_adult, g.is_japanese_developer,
  g.genres, fg.favorite_count;
