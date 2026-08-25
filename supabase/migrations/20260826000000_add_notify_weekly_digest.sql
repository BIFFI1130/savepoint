alter table public.profiles
  add column notify_weekly_digest boolean not null default true;
