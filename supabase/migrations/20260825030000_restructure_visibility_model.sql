-- 公開範囲モデルの再構成。
--
-- これまでは「記録ごとの公開範囲（private/mutual/public）」と「プロフィールの
-- 公開設定（is_public、真偽値）」という2層の設定が重なっており、分かりにくかった。
-- 新しいモデルでは役割を分離する:
--   - 記録（レビュー）ごと: 「非公開」「全公開」の2択のみ。「共有するかどうか」だけを持つ。
--   - プロフィール: 「非公開」「相互フォローのみ公開」「全公開」の3択。「誰に共有するか」を持つ。
-- 最終的な可視性は、記録が「全公開」かつプロフィールの設定で許可された相手、で決まる。

-- 1. game_logs.visibilityを2値化する。既存の'mutual'は「共有はする」の意で'public'に寄せる
--    （「誰に見せるか」の判断はプロフィール側に一本化するため）。
update public.game_logs set visibility = 'public' where visibility = 'mutual';

alter table public.game_logs drop constraint game_logs_visibility_check;
alter table public.game_logs
  add constraint game_logs_visibility_check check (visibility in ('private', 'public'));

-- 2. profilesにprofile_visibilityを追加し、is_publicから移行する。
alter table public.profiles
  add column profile_visibility text not null default 'private'
    check (profile_visibility in ('private', 'mutual', 'public'));

update public.profiles
set profile_visibility = case when is_public then 'public' else 'private' end;

-- 3. is_publicを参照していたビューを新しい列基準に書き換える
--    （列を削除する前に、依存しているビューを先に書き換える必要がある）。

-- 列名をis_publicからprofile_visibilityに変えるため、create or replaceでは
-- 列の位置的な名前変更ができない（Postgresの制約）。drop・createで作り直す。
drop view public.profiles_public;

create view public.profiles_public as
select
  id,
  username,
  display_name,
  avatar_url,
  profile_visibility,
  created_at
from public.profiles;

grant select on public.profiles_public to authenticated;

create or replace view public.favorite_games_feed as
select
  fg.user_id,
  fg.game_id,
  fg."position",
  fg.created_at,
  g.name as game_name,
  g.name_ja as game_name_ja,
  g.cover_url as game_cover_url,
  p.favorites_ranked
from public.favorite_games fg
join public.profiles p on p.id = fg.user_id
join public.games g on g.id = fg.game_id
where fg.user_id = auth.uid()
  or (
    p.profile_visibility = 'public'
    and exists (
      select 1 from public.follows f
      where f.followee_id = fg.user_id and f.follower_id = auth.uid()
    )
  )
  or (
    p.profile_visibility = 'mutual'
    and exists (
      select 1 from public.follows f
      where f.followee_id = fg.user_id and f.follower_id = auth.uid()
    )
    and exists (
      select 1 from public.follows f2
      where f2.follower_id = fg.user_id and f2.followee_id = auth.uid()
    )
  );

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
where gl.visibility = 'public'
  and (
    p.profile_visibility = 'public'
    or (
      p.profile_visibility = 'mutual'
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
  case when p.show_identity_in_public_reviews then p.username else null end
    as username,
  case when p.show_identity_in_public_reviews then p.display_name else null end
    as display_name,
  case when p.show_identity_in_public_reviews then p.avatar_url else null end
    as avatar_url,
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
where p.profile_visibility = 'public'
  and gl.visibility = 'public'
  and gl.status = 'played'
  and gl.user_id <> auth.uid()
  and (
    gl.rating is not null
    or (gl.review_text is not null and gl.review_text <> '')
  );

grant select on public.game_public_reviews to authenticated;

-- 4. 全ビューの書き換えが終わったので、不要になった列を削除する。
alter table public.profiles drop column is_public;
