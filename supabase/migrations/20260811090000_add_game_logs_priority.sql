-- 「遊びたい」リストの優先度（1=高, 2=中, 3=低。未設定はnull）を追加する。
alter table public.game_logs
  add column priority smallint check (priority is null or priority between 1 and 3);
