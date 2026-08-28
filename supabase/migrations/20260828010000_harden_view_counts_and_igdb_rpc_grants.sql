-- (1) ジャンル「すべて当てはまる」対応で追加された5引数版のigdb_*関数に対する
-- PUBLIC実行権限のrevoke漏れを修正する。20260820000100で一度同じパターンを修正
-- 済みだが、20260827010000でcreate or replaceにより新しい引数シグネチャの関数
-- （＝Postgres上は別オブジェクト）が作られた際、そちらへのrevokeが漏れていた。
-- Flutter側は常にこの5引数版を呼ぶため、実運用経路がPUBLIC（anon key・
-- サインアップ不要）実行可能なまま公開されていた。
revoke all on function public.igdb_weekly_releases(text[], text[], boolean, boolean, boolean) from public;
revoke all on function public.igdb_monthly_releases(text[], text[], boolean, boolean, boolean) from public;
revoke all on function public.igdb_calendar_releases(date, integer, text[], text[], boolean, boolean, boolean) from public;
revoke all on function public.igdb_top100(text[], text[], boolean, boolean, boolean) from public;

-- 旧4引数版はもう呼ばれていないため整理する。
drop function if exists public.igdb_weekly_releases(text[], text[], boolean, boolean);
drop function if exists public.igdb_monthly_releases(text[], text[], boolean, boolean);
drop function if exists public.igdb_calendar_releases(date, integer, text[], text[], boolean, boolean);
drop function if exists public.igdb_top100(text[], text[], boolean, boolean);

-- (2) 閲覧数分析（game_log_views・profile_views）が、DB側では自演水増し・
-- 重複水増しの両方を防げていなかった。「本人の閲覧はカウントしない」は
-- クライアント側のガードのみで、RLSのwith checkはviewer_idの本人確認しか
-- していなかったため、REST APIを直接叩けば無制限に水増しできた。

-- timestamptz→dateへのキャストはセッションのTimeZone設定に依存するためSTABLEであり、
-- そのままではユニークインデックスの式に使えない（IMMUTABLE要求）。UTC固定の
-- date_utc()として自前でIMMUTABLE宣言する（UTCはDSTを持たないため実質的に安全）。
create or replace function public.date_utc(ts timestamptz) returns date
  language sql immutable
  as $$ select (ts at time zone 'utc')::date $$;

-- 既存の自演閲覧・重複行があれば、新しい制約を追加する前に取り除いておく
-- （dev環境のみが対象、件数はごく少数の想定）。
delete from public.game_log_views v
using public.game_logs gl
where v.log_id = gl.id and v.viewer_id = gl.user_id;

delete from public.game_log_views a
using public.game_log_views b
where a.log_id = b.log_id
  and a.viewer_id = b.viewer_id
  and public.date_utc(a.viewed_at) = public.date_utc(b.viewed_at)
  and a.id > b.id;

delete from public.profile_views
where viewer_id = viewed_user_id;

delete from public.profile_views a
using public.profile_views b
where a.viewed_user_id = b.viewed_user_id
  and a.viewer_id = b.viewer_id
  and public.date_utc(a.viewed_at) = public.date_utc(b.viewed_at)
  and a.id > b.id;

-- game_logsのSELECTは本人の行のみ許可するRLS（game_logs_select_own）のため、
-- 閲覧者（他人のログを見ているviewer）からは対象ログのuser_idを直接は引けない
-- （素の subquery では常に0行＝NULLになりwith check自体が壊れてしまう）。
-- RLSをバイパスして所有者idだけを返す最小権限のsecurity definer関数を用意する。
create or replace function public.game_log_owner_id(p_log_id uuid) returns uuid
  language sql security definer stable
  set search_path = public
  as $$ select user_id from public.game_logs where id = p_log_id $$;

revoke all on function public.game_log_owner_id(uuid) from public;
grant execute on function public.game_log_owner_id(uuid) to authenticated;

drop policy "game_log_views_insert_any" on public.game_log_views;
create policy "game_log_views_insert_any"
  on public.game_log_views for insert
  to authenticated
  with check (
    auth.uid() = viewer_id
    and viewer_id <> public.game_log_owner_id(log_id)
  );

-- 1人のviewerが同じ記録を同じ日に何度見ても1カウントに倒す
-- （統計の趣旨にも合致し、無制限insertによる水増しも防ぐ）。
create unique index game_log_views_viewer_per_day_idx
  on public.game_log_views (log_id, viewer_id, public.date_utc(viewed_at));

drop policy "profile_views_insert_any" on public.profile_views;
create policy "profile_views_insert_any"
  on public.profile_views for insert
  to authenticated
  with check (
    auth.uid() = viewer_id
    and viewer_id <> viewed_user_id
  );

create unique index profile_views_viewer_per_day_idx
  on public.profile_views (viewed_user_id, viewer_id, public.date_utc(viewed_at));

-- (3) avatarsストレージバケットにファイルサイズ・MIMEタイプの制限が無く、
-- 公開バケットに任意種類のファイルを最大50MBほどアップロードできてしまっていた。
update storage.buckets
set file_size_limit = 5242880, -- 5MiB
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
where id = 'avatars';
