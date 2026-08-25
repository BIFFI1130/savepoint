-- follow_feed・game_public_reviewsビューにgame_logs.idを追加する。
-- 「いいね」機能でどのgame_logに対する操作かを特定するために必要。

create or replace view public.follow_feed as
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
  gl.clear_time_minutes,
  gl.id as log_id
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

create or replace view public.game_public_reviews as
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
  gl.clear_time_minutes,
  gl.id as log_id
from public.game_logs gl
join public.profiles p on p.id = gl.user_id
join public.games g on g.id = gl.game_id
where p.is_public = true
  and gl.visibility = 'public'
  and gl.status = 'played'
  and gl.user_id <> auth.uid()
  and (
    gl.rating is not null
    or (gl.review_text is not null and gl.review_text <> '')
  );

grant select on public.game_public_reviews to authenticated;
