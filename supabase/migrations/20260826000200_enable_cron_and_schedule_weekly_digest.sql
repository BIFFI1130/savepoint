-- 週間ダイジェスト通知の定期実行。本プロジェクトで初めてのcron連携。
-- notify-weekly-digest Edge FunctionにはユーザーのJWTが存在しない（cron起点のため）ので、
-- 独自の共有シークレット（x-cron-secretヘッダ）で検証する
-- （Edge Function側はsupabase secrets set CRON_SECRET=... で同じ値を設定する）。
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

select cron.schedule(
  'weekly-digest-notify',
  '0 1 * * 1', -- 毎週月曜 01:00 UTC = 10:00 JST
  $$
  select net.http_post(
    url := 'https://lsitiazbafrgeyklcckc.supabase.co/functions/v1/notify-weekly-digest',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', '90e03bd624d0a860d566a11e9f23bdc37a01a714b58f0942'
    ),
    body := '{}'::jsonb
  );
  $$
);
