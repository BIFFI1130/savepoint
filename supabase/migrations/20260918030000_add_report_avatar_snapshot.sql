-- プロフィール画像（アバター）はテキストレビューと違って通報時に「何が問題か」を
-- 特定する手段が無く、また avatars ストレージは同じパスへの upsert で上書きされる
-- 仕様のため、通報後に本人が画像を差し替えると問題の画像が跡形もなく消えてしまう。
-- 通報時点のavatar_urlをreports側にスナップショットとして残し、運営が後から
-- 確認できるようにする。あわせて「不適切なプロフィール画像」を通報理由として選べるようにする。

alter table public.reports
  add column reported_avatar_url text;

create or replace view public.reports_with_details as
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
  reported.display_name as reported_display_name,
  r.reported_avatar_url
from public.reports r
left join public.profiles reporter on reporter.id = r.reporter_id
left join public.profiles reported on reported.id = r.reported_user_id
order by
  case r.status when 'open' then 0 else 1 end,
  r.created_at desc;

create or replace function public.submit_report(
  p_reported_user_id uuid,
  p_reason text,
  p_detail text default null
) returns void
  language plpgsql
  security definer
  set search_path = public
  as $$
declare
  v_allowed boolean;
  v_avatar_url text;
begin
  if p_reason not in (
    'spam', 'harassment', 'inappropriate_content', 'inappropriate_avatar', 'other'
  ) then
    raise exception '不正な通報理由です';
  end if;

  -- 5分あたり5件まで。通常利用では十分な余裕を持たせつつ、連投による
  -- モデレーションキューへの負荷を防ぐ。
  v_allowed := public.check_rate_limit('report:user:' || auth.uid()::text, 5, 300);
  if not v_allowed then
    raise exception 'しばらく時間をおいてから再度お試しください';
  end if;

  -- クライアントから送られてきた値ではなく、通報時点のprofiles.avatar_urlを
  -- サーバー側で直接参照する（クライアント側で偽装・古い値を渡される余地を無くすため）。
  select avatar_url into v_avatar_url
  from public.profiles
  where id = p_reported_user_id;

  insert into public.reports (
    reporter_id, reported_user_id, reason, detail, reported_avatar_url
  )
  values (auth.uid(), p_reported_user_id, p_reason, p_detail, v_avatar_url);
end;
$$;

revoke all on function public.submit_report(uuid, text, text) from public;
grant execute on function public.submit_report(uuid, text, text) to authenticated;
