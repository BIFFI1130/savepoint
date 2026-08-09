-- SavePoint MVP 初期スキーマ
-- profiles / games / game_logs / igdb_tokens の作成、RLSポリシー、
-- auth.users 作成時に profiles を自動生成するトリガーを定義する。
--
-- このプロジェクトは Supabase の「Automatically expose new tables」を無効化した
-- 前提で書かれている。そのため、クライアント（Data API）に公開したいテーブルには
-- 各テーブル定義の直後で明示的に grant を行っている。grant を書かなければ、
-- RLSポリシーを用意していてもテーブルはData API経由で一切アクセスできない
-- （igdb_tokens はこれを逆手にとり、意図的にgrantを書かないことで完全に隠している）。
-- service_role はこれらのgrantとは無関係に常に全テーブルへアクセスできる。

grant usage on schema public to authenticated;

-- ============================================================
-- profiles: auth.users と1:1。サインアップ時にトリガーで自動作成される。
-- ============================================================
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text unique,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles_select_authenticated"
  on public.profiles for select
  to authenticated
  using (true);

create policy "profiles_insert_own"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- RLSポリシーに合わせて select/insert/update のみ許可（deleteポリシーは定義しない）
grant select, insert, update on public.profiles to authenticated;

-- auth.users に新規行が作られたら profiles にも自動で行を作る
create function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id)
  values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================
-- games: IGDB検索結果のキャッシュ。IGDBのidをそのままPKに使う。
-- クライアントからの書き込みは許可せず、Edge Function（service-role）のみが書き込む。
-- ============================================================
create table public.games (
  id bigint primary key,
  name text not null,
  cover_url text,
  first_release_date date,
  platforms text[] not null default '{}',
  summary text,
  raw_igdb_json jsonb,
  cached_at timestamptz not null default now()
);

alter table public.games enable row level security;

create policy "games_select_all"
  on public.games for select
  to authenticated
  using (true);

-- selectのみgrant。insert/update/deleteは意図的にgrantしない。
-- Edge Functionはservice-roleキーを使うため、grant/RLSどちらもバイパスして書き込める。
grant select on public.games to authenticated;

-- ============================================================
-- game_logs: ユーザーの記録（評価＋レビュー）。1ユーザー1ゲームにつき1件。
-- ============================================================
create table public.game_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  game_id bigint not null references public.games (id),
  rating smallint not null check (rating between 1 and 5),
  review_text text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, game_id)
);

create index game_logs_user_id_idx on public.game_logs (user_id);

alter table public.game_logs enable row level security;

create policy "game_logs_select_own"
  on public.game_logs for select
  to authenticated
  using (auth.uid() = user_id);

create policy "game_logs_insert_own"
  on public.game_logs for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "game_logs_update_own"
  on public.game_logs for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "game_logs_delete_own"
  on public.game_logs for delete
  to authenticated
  using (auth.uid() = user_id);

grant select, insert, update, delete on public.game_logs to authenticated;

-- ============================================================
-- igdb_tokens: Edge Function (igdb-proxy) が使う Twitch アクセストークンのキャッシュ。
-- クライアントからは一切アクセスさせない。ポリシーもgrantも意図的に何も書かない
-- （grantがなければData API経由では存在しないテーブル同然になり、
-- 　RLSポリシーもないため万一grantされても全行拒否される、二重の防御）。
-- ============================================================
create table public.igdb_tokens (
  id int primary key default 1,
  access_token text not null,
  expires_at timestamptz not null,
  constraint igdb_tokens_singleton check (id = 1)
);

alter table public.igdb_tokens enable row level security;
-- ポリシーを1つも作らないことで、service-role以外からのアクセスを完全に禁止する。
