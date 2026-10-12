-- 発売日の変更通知と、アプリ更新のお知らせ通知のための土台。
--
-- 【適用の前提】Vaultに次の2つのシークレットが登録済みであること
--  （値そのものはgit管理下に書かない。cron_secretは20260828000000で登録済み）:
--   select vault.create_secret('https://<project-ref>.supabase.co', 'project_url', 'Edge Function base URL for cron');
-- プロジェクトURLをVaultに置くのは、開発/本番で同じmigrationを使い回しても
-- 呼び出し先がずれないようにするため（過去のcron migrationはURLを直書きしている）。

-- 1. 通知の種別ごとON/OFF（既存のnotify_*と同じ考え方。既定は受け取る）。
alter table public.profiles
  add column if not exists notify_release_changes boolean not null default true,
  add column if not exists notify_app_update boolean not null default true;

-- 2. アップデート通知で「既に最新版の端末には送らない」ために、端末の版を記録する。
alter table public.device_tokens
  add column if not exists app_version text;

-- 3. 発売日変更の検知用。「遊びたい」に入れている人がいる作品だけを引く。
create index if not exists game_logs_want_to_play_game_id_idx
  on public.game_logs (game_id)
  where status = 'want_to_play';

create table if not exists public.release_date_changes (
  id bigint generated always as identity primary key,
  game_id bigint not null references public.games (id) on delete cascade,
  old_date date,
  new_date date,
  detected_at timestamptz not null default now(),
  processed_at timestamptz
);

-- ポリシーを定義しない＝service_role（Edge Function）以外は一切アクセスできない。
alter table public.release_date_changes enable row level security;

create index if not exists release_date_changes_unprocessed_idx
  on public.release_date_changes (detected_at)
  where processed_at is null;

-- gamesの発売日が変わったとき、その作品を「遊びたい」に入れている人がいれば検知を記録する。
-- gamesはIGDBのデータダンプ取り込み（igdb_apply_staged_dump）で毎日更新されるため、
-- 変更の検知をIGDB APIへの追加問い合わせなしにここで行える。
-- 発売済みの作品の日付補正はノイズなので、新旧どちらかが「今日以降または未定」の場合だけ記録する。
create or replace function public.queue_release_date_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (coalesce(new.first_release_date, 'infinity'::date) >= current_date
      or coalesce(old.first_release_date, 'infinity'::date) >= current_date)
     and exists (
       select 1 from public.game_logs gl
       where gl.game_id = new.id and gl.status = 'want_to_play'
     ) then
    insert into public.release_date_changes (game_id, old_date, new_date)
    values (new.id, old.first_release_date, new.first_release_date);
  end if;
  return new;
end;
$$;

revoke all on function public.queue_release_date_change() from public;

drop trigger if exists games_release_date_change on public.games;
create trigger games_release_date_change
  after update of first_release_date on public.games
  for each row
  when (old.first_release_date is distinct from new.first_release_date)
  execute function public.queue_release_date_change();

-- 4. 検知した変更を6時間おきに通知する（notify-release-changes）。
do $$
begin
  perform cron.unschedule('release-change-notify');
exception when others then
  null;
end;
$$;

select cron.schedule(
  'release-change-notify',
  '0 */6 * * *',
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
           || '/functions/v1/notify-release-changes',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (
        select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret'
      )
    ),
    body := '{}'::jsonb
  );
  $$
);
