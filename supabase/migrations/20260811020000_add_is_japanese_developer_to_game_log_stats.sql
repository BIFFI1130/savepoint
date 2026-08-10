-- game_log_stats にも is_japanese_developer を追加する。CREATE OR REPLACE VIEW は
-- 既存列の並びを変更できないため、新しい列は末尾に追加する。
create or replace view public.game_log_stats as
select
  g.id as game_id,
  g.name,
  g.cover_url,
  count(*) filter (where gl.status = 'played') as played_count,
  count(*) filter (where gl.status = 'want_to_play') as want_to_play_count,
  g.name_ja,
  g.is_adult,
  g.is_japanese_developer
from public.game_logs gl
join public.games g on g.id = gl.game_id
group by g.id, g.name, g.cover_url, g.name_ja, g.is_adult, g.is_japanese_developer;
