-- 「オレの推しゲー」機能：お気に入りのゲームを最大5件登録し、プロフィールで公開できる。
-- 順位あり（1位〜5位）か順不同かはユーザーが選べる（profiles.favorites_ranked）。

alter table public.profiles
  add column favorites_ranked boolean not null default true;

create table public.favorite_games (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  game_id bigint not null references public.games (id),
  position smallint not null,
  created_at timestamptz not null default now(),
  unique (user_id, game_id)
);

create index favorite_games_user_id_idx on public.favorite_games (user_id);

alter table public.favorite_games enable row level security;

create policy "favorite_games_select_own"
  on public.favorite_games for select
  to authenticated
  using (auth.uid() = user_id);

create policy "favorite_games_insert_own"
  on public.favorite_games for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "favorite_games_delete_own"
  on public.favorite_games for delete
  to authenticated
  using (auth.uid() = user_id);

grant select, insert, delete on public.favorite_games to authenticated;

-- 登録は最大5件まで（アプリ側でも制御するが、DB側でも二重に保証する）。
create function public.check_favorite_games_limit()
returns trigger
language plpgsql
as $$
begin
  if (select count(*) from public.favorite_games where user_id = new.user_id) >= 5 then
    raise exception 'favorite_games: 登録できるのは最大5件までです';
  end if;
  return new;
end;
$$;

create trigger favorite_games_limit_check
  before insert on public.favorite_games
  for each row execute procedure public.check_favorite_games_limit();

-- favorite_games_feed: 自分の一覧は常に見える。他人の一覧はfollow_feedと同じ基準
-- （フォロー中かつプロフィール公開）を満たす場合のみ見える。
create view public.favorite_games_feed as
select
  fg.user_id,
  fg.game_id,
  fg.position,
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
     p.is_public = true
     and exists (
       select 1 from public.follows f
       where f.followee_id = fg.user_id and f.follower_id = auth.uid()
     )
   );

grant select on public.favorite_games_feed to authenticated;
