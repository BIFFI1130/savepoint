-- タイトルの日本語表示可否の判定に使う。開発元（involved_companies.developer）に
-- 日本の会社（IGDBのcountry=392）が含まれる場合のみtrueにする。
alter table public.games
  add column is_japanese_developer boolean not null default false;
