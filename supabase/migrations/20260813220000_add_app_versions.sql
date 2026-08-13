-- TestFlight／Firebase App Distributionのように、ストアの自動更新チェックが効かない
-- 配布経路向けに、アプリ側で「最新ビルドかどうか」を自前でチェックするためのテーブル。
-- CI（codemagic.yaml）が各プラットフォームのビルド・パブリッシュ成功直後にservice roleで
-- upsertする。クライアントは起動時にこのテーブルを読み、自分のビルド番号が
-- latest_buildより古ければ強制アップデート画面を表示する。

create table public.app_versions (
  platform text primary key check (platform in ('ios', 'android')),
  latest_build integer not null,
  update_url text,
  updated_at timestamptz not null default now()
);

alter table public.app_versions enable row level security;

-- ログイン前（サインイン画面）でも古いビルドを検知できるよう、匿名でも読み取り可能にする。
create policy "app_versions_select_all"
  on public.app_versions for select
  to anon, authenticated
  using (true);

-- クライアントからの書き込みは一切許可しない（insert/updateポリシーを定義しない）。
-- CIからの書き込みはservice roleを使うため、RLSやgrantとは無関係に常に許可される。
grant select on public.app_versions to anon, authenticated;
