-- 「遊んだ」記録に「クリアした」フラグと、クリアまでにかかった時間（任意・分単位）を追加する。
alter table public.game_logs
  add column is_cleared boolean not null default false,
  add column clear_time_minutes integer check (clear_time_minutes is null or clear_time_minutes > 0);
