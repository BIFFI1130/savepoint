-- reportsテーブルへの直接insertにはレート制限が無く、悪意あるユーザーが有効なJWTさえ
-- あれば偽の通報を高速に繰り返し送りつけ、モデレーションキュー（reports_with_details）
-- を実質DoSできる問題があった（第1弾監査S-5）。専用のSECURITY DEFINER RPCへ一本化し、
-- テーブルへの直接insert経路を塞いだ上でレート制限を掛ける。

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
begin
  if p_reason not in ('spam', 'harassment', 'inappropriate_content', 'other') then
    raise exception '不正な通報理由です';
  end if;

  -- 5分あたり5件まで。通常利用では十分な余裕を持たせつつ、連投による
  -- モデレーションキューへの負荷を防ぐ。
  v_allowed := public.check_rate_limit('report:user:' || auth.uid()::text, 5, 300);
  if not v_allowed then
    raise exception 'しばらく時間をおいてから再度お試しください';
  end if;

  insert into public.reports (reporter_id, reported_user_id, reason, detail)
  values (auth.uid(), p_reported_user_id, p_reason, p_detail);
end;
$$;

revoke all on function public.submit_report(uuid, text, text) from public;
grant execute on function public.submit_report(uuid, text, text) to authenticated;

-- テーブルへの直接insert経路を塞ぎ、上記RPC経由のみに一本化する。
drop policy "reports_insert_own" on public.reports;
revoke insert on public.reports from authenticated;
