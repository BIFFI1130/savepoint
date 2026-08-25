-- フォロー中ユーザーの週間ダイジェスト通知の集計用関数。
--
-- follow_feedビューはauth.uid()に依存しており、service_role（cron/Edge Function）
-- からは「呼び出し元ユーザー」という概念が無いため使えない。そのため、
-- follow_feedと同じ可視性ロジック（記録がpublicかつ、投稿者のプロフィール設定で
-- 許可された相手）を、素のSQLでフォロワーごとに再実装する。
create or replace function public.weekly_digest_recipients()
returns table (user_id uuid, log_count bigint)
language sql
security definer
set search_path = public
as $$
  select f.follower_id as user_id, count(*) as log_count
  from follows f
  join game_logs gl on gl.user_id = f.followee_id
  join profiles owner on owner.id = gl.user_id
  where gl.visibility = 'public'
    and gl.created_at > now() - interval '7 days'
    and (
      owner.profile_visibility = 'public'
      or (
        owner.profile_visibility = 'mutual'
        and exists (
          select 1 from follows f2
          where f2.follower_id = owner.id and f2.followee_id = f.follower_id
        )
      )
    )
  group by f.follower_id;
$$;

grant execute on function public.weekly_digest_recipients() to service_role;
