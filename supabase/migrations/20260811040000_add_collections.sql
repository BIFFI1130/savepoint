-- コレクション機能: collections / collection_games テーブルと集計ビュー collection_summary を追加。
-- game_logs と同じスタイルで user_id を直接持たせ、シンプルな auth.uid() = user_id のRLSにする。

create table public.collections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index collections_user_id_idx on public.collections (user_id);

alter table public.collections enable row level security;

create policy "collections_select_own"
  on public.collections for select
  to authenticated
  using (auth.uid() = user_id);

create policy "collections_insert_own"
  on public.collections for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "collections_update_own"
  on public.collections for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "collections_delete_own"
  on public.collections for delete
  to authenticated
  using (auth.uid() = user_id);

grant select, insert, update, delete on public.collections to authenticated;

-- ============================================================
-- collection_games: コレクションに含まれる作品。user_idを冗長に持たせ、
-- game_logsと同じ直接比較のRLSにする（collectionsとのJOINを不要にする）。
-- ============================================================
create table public.collection_games (
  collection_id uuid not null references public.collections (id) on delete cascade,
  game_id bigint not null references public.games (id),
  user_id uuid not null references public.profiles (id) on delete cascade,
  added_at timestamptz not null default now(),
  primary key (collection_id, game_id)
);

create index collection_games_user_id_idx on public.collection_games (user_id);

alter table public.collection_games enable row level security;

create policy "collection_games_select_own"
  on public.collection_games for select
  to authenticated
  using (auth.uid() = user_id);

create policy "collection_games_insert_own"
  on public.collection_games for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "collection_games_delete_own"
  on public.collection_games for delete
  to authenticated
  using (auth.uid() = user_id);

grant select, insert, delete on public.collection_games to authenticated;

-- ============================================================
-- collection_summary: コレクション一覧画面用の集計ビュー（件数・直近追加カバー4枚）。
-- security_invoker=true により、呼び出したユーザーの権限で collections/collection_games の
-- RLSがそのまま適用される（= 自分のコレクションしか返らない。game_log_statsとは異なり
-- 個人情報を含むため、RLSをバイパスするデフォルトのビュー所有者権限では作らない）。
-- ============================================================
create view public.collection_summary
with (security_invoker = true) as
select
  c.id,
  c.user_id,
  c.name,
  c.created_at,
  c.updated_at,
  count(cg.game_id) as game_count,
  coalesce(
    (
      select array_agg(g.cover_url order by cg2.added_at desc)
      from (
        select cg_inner.game_id, cg_inner.added_at
        from public.collection_games cg_inner
        where cg_inner.collection_id = c.id
        order by cg_inner.added_at desc
        limit 4
      ) cg2
      join public.games g on g.id = cg2.game_id
    ),
    '{}'
  ) as cover_urls
from public.collections c
left join public.collection_games cg on cg.collection_id = c.id
group by c.id;

grant select on public.collection_summary to authenticated;
