alter table public.profiles
  add column notify_new_like boolean not null default true;

-- notify-new-like Edge Functionが、いいねされたログの所有者・ゲームIDを
-- service_roleで引くために必要（既知のGRANT漏れパターン、事前に付与しておく）。
grant select on public.game_logs to service_role;
