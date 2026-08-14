-- 通報の運営側確認手段。
--
-- これまでreportsテーブルには一般ユーザー向けのinsertポリシーしかなく、運営が
-- Supabaseダッシュボード（service role、RLSをバイパスする）からTable Editorで
-- 直接見る想定だった。ただしそのままだと reporter_id / reported_user_id が
-- UUIDのままで、誰が誰を通報したのか一目で分からない。また対応済みかどうかを
-- 追跡する手段もなかった。
--
-- このマイグレーションで以下を追加する:
--   1. reportsに対応状況を追跡するstatus/resolved_at/resolved_note列を追加
--   2. ユーザー名・表示名を結合した確認用ビュー reports_with_details を追加
--      （一般ユーザーには一切公開しない。SELECT権限をanon/authenticatedへ
--      付与していないため、PostgREST経由（アプリ側）からは見えず、Supabase
--      ダッシュボードのTable Editor/SQL Editor（service role権限）からのみ
--      参照できる）

alter table public.reports
  add column status text not null default 'open'
    check (status in ('open', 'resolved', 'dismissed')),
  add column resolved_at timestamptz,
  add column resolved_note text;

create view public.reports_with_details as
select
  r.id,
  r.status,
  r.reason,
  r.detail,
  r.created_at,
  r.resolved_at,
  r.resolved_note,
  r.reporter_id,
  reporter.username as reporter_username,
  reporter.display_name as reporter_display_name,
  r.reported_user_id,
  reported.username as reported_username,
  reported.display_name as reported_display_name
from public.reports r
left join public.profiles reporter on reporter.id = r.reporter_id
left join public.profiles reported on reported.id = r.reported_user_id
order by
  case r.status when 'open' then 0 else 1 end,
  r.created_at desc;
