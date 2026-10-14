-- 週間ダイジェストのcronの呼び出し先を、環境ごとのプロジェクトURL（Vaultのproject_url）に直す。
--
-- 20260826000200 / 20260828000000 は呼び出し先URLを開発プロジェクト
-- （lsitiazbafrgeyklcckc）に直書きしていたため、同じmigrationを適用した本番DBでも
-- 開発プロジェクトのnotify-weekly-digestを呼んでおり、本番ユーザーには届いていなかった
-- （2026-10-14に本番のcron.jobで確認）。
--
-- 前提: Vaultにproject_urlとcron_secretが登録済みであること
-- （20261012000000のコメント参照）。
do $$
begin
  perform cron.unschedule('weekly-digest-notify');
exception when others then
  null;
end;
$$;

select cron.schedule(
  'weekly-digest-notify',
  '0 1 * * 1', -- 毎週月曜 01:00 UTC = 10:00 JST
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
           || '/functions/v1/notify-weekly-digest',
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
