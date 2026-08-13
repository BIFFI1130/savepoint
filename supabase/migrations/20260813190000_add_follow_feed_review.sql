-- follow_feedビューに評価（星）・レビュー本文・ネタバレフラグ・クリア情報を追加する。
-- 可視性の扱いは既存のまま（private行は不可視、mutual行は相互フォロー時のみ可視、
-- public行は自分をフォローしている全員に可視）。これらの列は「遊んだ／遊びたい」
-- ステータスと同じ行に乗せるだけなので、追加の可視性チェックは不要。
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
