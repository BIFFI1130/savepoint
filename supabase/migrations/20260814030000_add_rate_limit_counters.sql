-- レート制限用のカウンタテーブルと、それを安全に（並行呼び出しでも競合なく）
-- 増分・判定するためのRPC関数。
--
-- 主な用途: igdb-proxy Edge Function。verify_jwt=trueは設定済みだが、これは
-- 「有効なJWTが付いているか」しか見ておらず、anon keyそのものも有効なJWTである
-- ため、サインアップ前のユーザー（＝anon keyさえ持っていれば誰でも）でも
-- 呼び出せてしまう。IGDB/Twitch・Google Translateの利用枠を無関係な大量呼び出しで
-- 消費されないよう、呼び出し元ごと（サインイン済みならuser_id、それ以外はIP）に
-- 簡易なウィンドウ制限を課す。

create table public.rate_limit_counters (
  key text primary key,
  window_start timestamptz not null,
  request_count integer not null default 0
);

-- key: 呼び出し元を識別する文字列（例: "igdb-proxy:user:<uuid>" や "igdb-proxy:ip:<ip>"）
-- p_limit: p_window_seconds秒間に許容する最大リクエスト数
-- 戻り値: true = 制限内（許可）, false = 制限超過（拒否すべき）
create or replace function public.check_rate_limit(
  p_key text,
  p_limit integer,
  p_window_seconds integer
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := now();
  v_count integer;
begin
  insert into public.rate_limit_counters (key, window_start, request_count)
  values (p_key, v_now, 1)
  on conflict (key) do update
    set
      request_count = case
        when rate_limit_counters.window_start <= v_now - make_interval(secs => p_window_seconds)
          then 1
        else rate_limit_counters.request_count + 1
      end,
      window_start = case
        when rate_limit_counters.window_start <= v_now - make_interval(secs => p_window_seconds)
          then v_now
        else rate_limit_counters.window_start
      end
  returning request_count into v_count;

  return v_count <= p_limit;
end;
$$;

grant execute on function public.check_rate_limit(text, integer, integer) to service_role;
