-- 星評価を1刻み（smallint）から0.5刻み（numeric）に変更する。
-- 既存の範囲チェック制約（1〜5）を、0.5刻みであることも検証する制約に置き換える。
-- avg(gl.rating)を使うgame_log_statsビュー（20260811030000）は型に依存しないため変更不要。
-- follow_feed・game_log_statsの両ビューがrating列に依存しているため、型変更の間だけ
-- 一旦dropし、直後に全く同じ定義で作り直す（それぞれ20260813190000・20260811030000と同一）。
drop view public.follow_feed;
drop view public.game_log_stats;

alter table public.game_logs
  drop constraint game_logs_rating_check;

alter table public.game_logs
  alter column rating type numeric(2, 1) using rating::numeric(2, 1);

alter table public.game_logs
  add constraint game_logs_rating_check
  check (rating is null or (rating between 1 and 5 and rating * 2 = round(rating * 2)));

create view public.follow_feed as
select
  gl.user_id,
  p.username,
  p.display_name,
  p.avatar_url,
  gl.game_id,
  g.name as game_name,
  g.name_ja as game_name_ja,
  g.cover_url as game_cover_url,
  gl.status,
  gl.created_at,
  gl.updated_at,
  gl.rating,
  gl.review_text,
  gl.has_spoiler,
  gl.is_cleared,
  gl.clear_time_minutes
from public.game_logs gl
join public.profiles p on p.id = gl.user_id
join public.games g on g.id = gl.game_id
join public.follows f
  on f.followee_id = gl.user_id
  and f.follower_id = auth.uid()
where p.is_public = true
  and (
    gl.visibility = 'public'
    or (
      gl.visibility = 'mutual'
      and exists (
        select 1 from public.follows f2
        where f2.follower_id = gl.user_id and f2.followee_id = auth.uid()
      )
    )
  );

grant select on public.follow_feed to authenticated;

create view public.game_log_stats as
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

grant select on public.game_log_stats to authenticated;
