-- フォロー内リーダーボード（直近7日間の記録数ランキング）。
-- follow_feedビューがauth.uid()スコープ・可視性ルール込みで安全に絞り込み済みのため、
-- その上に集計を重ねるだけでRLS的に安全（follow_feed自体もauthenticatedにselect済み）。
create view public.follow_feed_leaderboard as
select
  user_id,
  username,
  display_name,
  avatar_url,
  count(*) as log_count
from public.follow_feed
where created_at > now() - interval '7 days'
group by user_id, username, display_name, avatar_url
order by log_count desc;

grant select on public.follow_feed_leaderboard to authenticated;
