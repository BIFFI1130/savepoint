-- タイムラインの「いいね」機能。
--
-- game_log_likesは本人の行のみselect/insert/delete可能（他人が誰にいいねしたかを
-- 直接テーブルから読めないようにする）。いいね数（誰が押したかを問わない集計値）は
-- game_log_like_countsビューで別途公開する。favorite_count（game_log_stats）と
-- 同じ考え方：ビュー自体はマイグレーション実行ロール（RLSをバイパスする）の権限で
-- 集計するため、個々のユーザーを特定できない集計値のみを安全に公開できる。

create table public.game_log_likes (
  id uuid primary key default gen_random_uuid(),
  log_id uuid not null references public.game_logs (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (log_id, user_id)
);

create index game_log_likes_log_id_idx on public.game_log_likes (log_id);
create index game_log_likes_user_id_idx on public.game_log_likes (user_id);

alter table public.game_log_likes enable row level security;

create policy "game_log_likes_select_own"
  on public.game_log_likes for select
  to authenticated
  using (auth.uid() = user_id);

create policy "game_log_likes_insert_own"
  on public.game_log_likes for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "game_log_likes_delete_own"
  on public.game_log_likes for delete
  to authenticated
  using (auth.uid() = user_id);

grant select, insert, delete on public.game_log_likes to authenticated;

create view public.game_log_like_counts as
select log_id, count(*) as like_count
from public.game_log_likes
group by log_id;

grant select on public.game_log_like_counts to authenticated;
