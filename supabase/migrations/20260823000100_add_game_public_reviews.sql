-- ゲーム単位で「フォロー関係を問わない」公開レビュー一覧を取得するためのビュー。
-- follow_feedと異なりfollowsテーブルとのJOINを行わない（フォロー中の相手に限定しない）。
-- 列構成をfollow_feedと完全に一致させ、Flutter側でFollowFeedEntryモデルを
-- そのまま再利用できるようにしている。
-- サブスク特典（「みんなのレビュー」）としてゲーム詳細画面から利用する想定。
create view public.game_public_reviews as
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
where p.is_public = true
  and gl.visibility = 'public'
  and gl.status = 'played'
  and gl.user_id <> auth.uid()
  and (
    gl.rating is not null
    or (gl.review_text is not null and gl.review_text <> '')
  );

grant select on public.game_public_reviews to authenticated;
