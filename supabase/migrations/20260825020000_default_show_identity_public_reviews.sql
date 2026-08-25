-- 「みんなのレビュー」の身元表示のデフォルトを全公開に変更する。
-- 正式リリース前で対象ユーザーが少なく、まだ誰も設定を変更していない前提のため、
-- 既存行もあわせて更新する（正式リリース後にこの列のデフォルトを変える場合は
-- 既存ユーザーの意図しない公開を避けるため、既存行の一括更新は行わないこと）。
alter table public.profiles
  alter column show_identity_in_public_reviews set default true;

update public.profiles set show_identity_in_public_reviews = true;
