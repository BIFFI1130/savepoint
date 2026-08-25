-- 「みんなのレビュー」の身元表示（オプトイン、デフォルトOFF＝既存ユーザーの挙動は
-- 変えない）。trueのユーザーのみ、game_public_reviewsでusername/display_name/
-- avatar_urlが実際の値になる（falseの間はnullを返す＝クライアント側の匿名表示と
-- 二重に安全側で守る。REST APIを直接叩かれても身元は漏れない）。
alter table public.profiles
  add column show_identity_in_public_reviews boolean not null default false;

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
where p.is_public = true
  and gl.visibility = 'public'
  and gl.status = 'played'
  and gl.user_id <> auth.uid()
  and (
    gl.rating is not null
    or (gl.review_text is not null and gl.review_text <> '')
  );

grant select on public.game_public_reviews to authenticated;

-- サブスク特典「閲覧数の分析」用。誰が見たかではなく件数のみを本人に見せる。
-- viewerとowner本人が同一の場合はカウントしない（クライアント側で挿入をスキップする）。

create table public.game_log_views (
  id uuid primary key default gen_random_uuid(),
  log_id uuid not null references public.game_logs (id) on delete cascade,
  viewer_id uuid not null references public.profiles (id) on delete cascade,
  viewed_at timestamptz not null default now()
);

create index game_log_views_log_id_idx on public.game_log_views (log_id);

alter table public.game_log_views enable row level security;

create policy "game_log_views_insert_any"
  on public.game_log_views for insert
  to authenticated
  with check (auth.uid() = viewer_id);

grant insert on public.game_log_views to authenticated;

create view public.game_log_view_counts as
select log_id, count(*) as view_count
from public.game_log_views
group by log_id;

grant select on public.game_log_view_counts to authenticated;

create table public.profile_views (
  id uuid primary key default gen_random_uuid(),
  viewed_user_id uuid not null references public.profiles (id) on delete cascade,
  viewer_id uuid not null references public.profiles (id) on delete cascade,
  viewed_at timestamptz not null default now()
);

create index profile_views_viewed_user_id_idx on public.profile_views (viewed_user_id);

alter table public.profile_views enable row level security;

create policy "profile_views_insert_any"
  on public.profile_views for insert
  to authenticated
  with check (auth.uid() = viewer_id);

grant insert on public.profile_views to authenticated;

create view public.profile_view_counts as
select viewed_user_id, count(*) as view_count
from public.profile_views
group by viewed_user_id;

grant select on public.profile_view_counts to authenticated;
