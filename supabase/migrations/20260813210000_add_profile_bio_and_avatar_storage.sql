-- プロフィール確認・編集ページ用の拡張。
-- 追加項目: ゲーム歴（自由記述）・好きなジャンル（複数選択）。
-- あわせて、プロフィール画像をユーザー自身がアップロードできるよう
-- Supabase Storageに"avatars"バケットを作成する（既存のavatar_urlはこのバケットの
-- 公開URLを指すようになる）。

alter table public.profiles
  add column game_history text,
  add column favorite_genres text[] not null default '{}';

-- ============================================================
-- avatars バケット: 公開読み取り可、本人のみ自分のフォルダ配下に書き込み可。
-- オブジェクトのパスは "{user_id}/avatar.jpg" のように本人のuidをプレフィックスにする
-- 運用を前提とし、storage.foldername(name)の先頭要素がauth.uid()と一致する場合のみ
-- 書き込み・更新・削除を許可する。
-- ============================================================
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy "avatars_public_read"
  on storage.objects for select
  to public
  using (bucket_id = 'avatars');

create policy "avatars_insert_own_folder"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "avatars_update_own_folder"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "avatars_delete_own_folder"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
