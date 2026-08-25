-- 「新しいフォロワー」通知の種別ごとON/OFFを、プッシュ通知の登録自体（device_tokens）
-- とは独立して行えるようにする。notify_following_reviewsと同じ考え方：
-- device_tokensが有る＝プッシュ通知そのものは有効、その上でどの種別を受け取るかを
-- この列で個別に制御する。
alter table public.profiles
  add column notify_new_follower boolean not null default true;
