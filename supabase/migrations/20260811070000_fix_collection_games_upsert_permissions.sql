-- addGame() は upsert()（INSERT ... ON CONFLICT DO UPDATE）を使うため、
-- 実際に競合が発生しない新規追加でもPostgres側でUPDATE権限のチェックが必要になる。
-- 元のマイグレーションではselect/insert/deleteしか付与しておらず、
-- 「permission denied for table collection_games」で追加操作自体が失敗していた。

create policy "collection_games_update_own"
  on public.collection_games for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

grant update on public.collection_games to authenticated;
