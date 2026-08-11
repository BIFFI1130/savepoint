-- 「つながり」機能（フォロー・ブロック・通報）の土台。
--
-- 方針:
-- - プロフィールはデフォルト非公開（is_public = false）。本人が公開に設定した場合のみ、
--   フォロワーに「遊んだ／遊びたい」のステータス一覧を見せる。評価・レビュー本文・
--   ネタバレフラグ・クリア情報・優先度は一切含めない（follow_feedビューを参照）。
-- - フォローはリクエスト承認制ではなく即時反映（v1はシンプルさを優先）。ただし
--   ブロック関係がある場合はフォローできない。
-- - 通報は運営（Supabaseダッシュボード経由のservice role）のみが閲覧できる。
--   一般ユーザー向けのselectポリシーはあえて定義しない。

alter table public.profiles
  add column is_public boolean not null default false;

-- ============================================================
-- blocks: ブロック関係。ブロックした本人だけが自分のブロック一覧を見られる
-- （ブロックされた側には通知しない）。followsより先に作る
-- （follows_insert_ownポリシーがblocksを参照するため）。
-- ============================================================
create table public.blocks (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);

alter table public.blocks enable row level security;

create policy "blocks_select_own"
  on public.blocks for select
  to authenticated
  using (auth.uid() = blocker_id);

create policy "blocks_insert_own"
  on public.blocks for insert
  to authenticated
  with check (auth.uid() = blocker_id and blocker_id <> blocked_id);

create policy "blocks_delete_own"
  on public.blocks for delete
  to authenticated
  using (auth.uid() = blocker_id);

grant select, insert, delete on public.blocks to authenticated;

-- ============================================================
-- follows: フォロー関係。
-- ============================================================
create table public.follows (
  follower_id uuid not null references public.profiles (id) on delete cascade,
  followee_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followee_id)
);

create index follows_followee_id_idx on public.follows (followee_id);

alter table public.follows enable row level security;

-- 自分がフォローしている相手、および自分をフォローしている相手の一覧は見える。
create policy "follows_select_own"
  on public.follows for select
  to authenticated
  using (auth.uid() = follower_id or auth.uid() = followee_id);

-- 自分自身はフォローできない。ブロック関係（どちら向きでも）がある場合はフォローできない。
create policy "follows_insert_own"
  on public.follows for insert
  to authenticated
  with check (
    auth.uid() = follower_id
    and follower_id <> followee_id
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = follower_id and b.blocked_id = followee_id)
         or (b.blocker_id = followee_id and b.blocked_id = follower_id)
    )
  );

create policy "follows_delete_own"
  on public.follows for delete
  to authenticated
  using (auth.uid() = follower_id);

grant select, insert, delete on public.follows to authenticated;

-- ブロックした時点で、両方向の既存フォロー関係を解消する。
-- 相手側（blocked_id）が持つフォロー行はブロックした本人の行ではないため、
-- RLSを経由せず処理できるようsecurity definerにする。
create function public.handle_new_block()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  delete from public.follows
  where (follower_id = new.blocker_id and followee_id = new.blocked_id)
     or (follower_id = new.blocked_id and followee_id = new.blocker_id);
  return new;
end;
$$;

create trigger on_block_created
  after insert on public.blocks
  for each row execute procedure public.handle_new_block();

-- ============================================================
-- reports: ユーザー通報。一般ユーザーは投稿のみ可能（自分の通報も含め閲覧不可）。
-- 運営はSupabaseダッシュボード（service role）から確認する。
-- ============================================================
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  reported_user_id uuid references public.profiles (id) on delete cascade,
  reason text not null,
  detail text,
  created_at timestamptz not null default now()
);

alter table public.reports enable row level security;

create policy "reports_insert_own"
  on public.reports for insert
  to authenticated
  with check (auth.uid() = reporter_id);

grant insert on public.reports to authenticated;

-- ============================================================
-- follow_feed: フォロー中のユーザーの「遊んだ／遊びたい」ステータス一覧。
-- 評価・レビュー・ネタバレ・クリア情報・優先度は含めない（見せるのはステータスのみ）。
-- このビューはマイグレーション実行ロール（BYPASSRLS）が所有するためgame_logsの
-- RLSをバイパスするが、auth.uid()とfollowsテーブルで呼び出しユーザーごとに絞り込む。
-- ============================================================
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
  gl.updated_at
from public.game_logs gl
join public.profiles p on p.id = gl.user_id
join public.games g on g.id = gl.game_id
join public.follows f
  on f.followee_id = gl.user_id
  and f.follower_id = auth.uid()
where p.is_public = true;

grant select on public.follow_feed to authenticated;
