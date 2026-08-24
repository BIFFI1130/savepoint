-- notify-new-follower Edge Functionのadminクライアント（service_role）が
-- device_tokens・profilesを直接クエリできるよう、明示的にgrantする。
-- このプロジェクトではservice_roleもRLSはバイパスするが、テーブルへの
-- Data APIアクセス自体は他ロール同様に明示的なgrantが必要
-- （app_versions・rate_limit_counters と同じ既知のパターン）。
grant select, insert, update, delete on public.device_tokens to service_role;
grant select on public.profiles to service_role;
