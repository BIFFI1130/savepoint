-- フォロー中ユーザーの新着レビュー通知の設定（プッシュ通知自体はdevice_tokensの
-- 登録有無で制御されるが、これとは別に「新しいフォロワー」通知だけ受け取り
-- 「新着レビュー」は受け取りたくない、という個別設定を可能にする）。
alter table public.profiles
  add column notify_following_reviews boolean not null default true;

-- notify-new-review Edge Functionのadminクライアント（service_role）がフォロワー
-- 一覧を取得するためにfollowsテーブルへのselectが必要。device_tokens・profilesで
-- 既に発生した「service_roleへのgrant漏れ」と同じパターンを事前に防ぐ。
grant select on public.follows to service_role;
