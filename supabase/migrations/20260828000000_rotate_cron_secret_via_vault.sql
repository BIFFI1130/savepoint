-- 週間ダイジェストcronジョブのx-cron-secretをローテーションする。
-- 元の値（20260826000200で設定）は公開GitHubリポジトリにコミットされてしまっており、
-- 実質漏洩済みとして扱う必要があるため、値をSupabase Vaultへ移し、以後は平文を
-- migrationにベタ書きしない運用に変える。
--
-- 前提: このmigrationを適用する前に、Supabase Dashboard（SQL Editor）等の
-- 信頼できる経路から一度だけ以下を実行し、Vaultにシークレットを登録しておくこと
-- （値そのものはgit管理下のファイルには一切書かない。詳細はsupabase/SECRETS.local.md参照）:
--   select vault.create_secret('<新しいシークレット値>', 'cron_secret', 'notify-weekly-digest cron auth');
-- Edge Function側のCRON_SECRET（`supabase secrets set CRON_SECRET=...`）も同じ値に
-- 更新すること。
select cron.unschedule('weekly-digest-notify');

select cron.schedule(
  'weekly-digest-notify',
  '0 1 * * 1', -- 毎週月曜 01:00 UTC = 10:00 JST
  $$
  select net.http_post(
    url := 'https://lsitiazbafrgeyklcckc.supabase.co/functions/v1/notify-weekly-digest',
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
