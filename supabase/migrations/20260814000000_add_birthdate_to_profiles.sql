-- 生年月（年・月のみ、日は取得しない）。年齢確認（成人向け作品の表示可否）に使う。
alter table public.profiles
  add column birth_year integer check (birth_year >= 1900),
  add column birth_month integer check (birth_month between 1 and 12);
