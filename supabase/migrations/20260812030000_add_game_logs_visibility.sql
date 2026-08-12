-- ゲーム単位の公開範囲設定。
-- private: 自分にのみ表示。mutual: 相互フォロー関係にあるユーザーにのみ表示。
-- public: 自分をフォローしているユーザー全員に表示（従来の挙動）。
alter table public.game_logs
  add column visibility text not null default 'public'
    check (visibility in ('private', 'mutual', 'public'));

-- follow_feed: game_logs.visibilityを踏まえて再定義する。
-- private行は誰にも見せず、mutual行は「自分(gl.user_id)が閲覧者(auth.uid())を
-- フォローしている」場合のみ見せる（follows_select_ownで既に「auth.uid() = follower_id or
-- auth.uid() = followee_id」の行は見えるため、追加のexistsチェックで十分）。
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
  gl.updated_at
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
