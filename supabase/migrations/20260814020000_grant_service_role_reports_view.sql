-- reports / reports_with_details も、他テーブルと同様にservice_roleへの明示的な
-- GRANTが無いとPostgREST経由（service roleキーでのAPIアクセス）から参照できない。
-- Supabaseダッシュボードの Table Editor / SQL Editor は直接Postgresに
-- postgresロールで接続するためこのGRANTが無くても閲覧できるが、運営が
-- スクリプト等からservice roleキー経由で確認・集計したいケースに備えて付与しておく。

grant select, update on public.reports to service_role;
grant select on public.reports_with_details to service_role;
