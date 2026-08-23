-- game_log_stats に favorite_count（「推しゲー」登録数、全ユーザー集計）を追加する。
-- favorite_gamesはuser_id本人のみselectできるRLSだが、このビュー自体はマイグレーション
-- 実行ロール（RLSをバイパスする）の権限で集計するため、既存のavg_rating等と同様に
-- 個々のユーザーを特定できない集計値のみを安全に公開できる。
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
  coalesce(fg.favorite_count, 0) as favorite_count
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
