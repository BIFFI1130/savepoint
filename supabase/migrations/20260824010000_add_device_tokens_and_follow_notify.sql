-- device_tokens: サーバー起点のプッシュ通知（フォロー中ユーザーの新着）を送るための
-- FCM（Android）/ APNs経由（iOS）宛先トークン。1ユーザーが複数端末を持つ場合もあるため
-- user_idではなくtoken自体を一意キーにする（再登録・機種変更時はupsertで上書き）。
create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  token text not null unique,
  platform text not null check (platform in ('ios', 'android')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.device_tokens enable row level security;

create policy "device_tokens_select_own"
  on public.device_tokens for select
  to authenticated
  using (auth.uid() = user_id);

create policy "device_tokens_insert_own"
  on public.device_tokens for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "device_tokens_update_own"
  on public.device_tokens for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "device_tokens_delete_own"
  on public.device_tokens for delete
  to authenticated
  using (auth.uid() = user_id);

grant select, insert, update, delete on public.device_tokens to authenticated;

-- notify-follow-activity Edge Functionが、通知対象（フォロワーのうち可視性条件を
-- 満たす人だけ）の通知トークンを絞り込むための関数。follow_feedビューと同じ可視性
-- ルール（is_public・visibility）を、特定の投稿者(p_actor_id)・公開範囲(p_visibility)
-- について評価する。service_role（RLSを常にバイパスする）からのみ呼ばれる前提で、
-- 他ユーザーの通知トークンを返すため、authenticatedへの実行権限は明示的に与えない。
create function public.eligible_follower_tokens(p_actor_id uuid, p_visibility text)
returns table (token text, platform text)
language sql
stable
as $$
  select dt.token, dt.platform
  from public.follows f
  join public.device_tokens dt on dt.user_id = f.follower_id
  join public.profiles p on p.id = f.followee_id
  where f.followee_id = p_actor_id
    and p.is_public = true
    and (
      p_visibility = 'public'
      or (
        p_visibility = 'mutual'
        and exists (
          select 1 from public.follows f2
          where f2.follower_id = f.followee_id and f2.followee_id = f.follower_id
        )
      )
    );
$$;

revoke execute on function public.eligible_follower_tokens(uuid, text) from public;
