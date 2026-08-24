-- 「フォロー中ユーザーの新着通知」ではなく「新しくフォローされたときの通知」が
-- 本来の要件だったため、前者専用に用意したeligible_follower_tokens関数
-- （game_logsの可視性ルールに基づくフォロワー絞り込み）は不要になった。
-- device_tokensテーブル自体は新しい通知（notify-new-follower Edge Function）でも
-- そのまま使うため変更しない。
drop function if exists public.eligible_follower_tokens(uuid, text);
