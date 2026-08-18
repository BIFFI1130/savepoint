-- rate_limit_countersはigdb-proxyのcheck_rate_limit（SECURITY DEFINER関数）からのみ
-- 更新される内部テーブルで、クライアントが直接読み書きする想定はない。作成時に
-- RLSの有効化を忘れており、Supabaseのセキュリティアドバイザーで
-- 「Table publicly accessible（RLS未設定）」として検出された。
-- ポリシーを追加せずRLSのみ有効化することで、anon/authenticatedからの直接アクセスを
-- 全て遮断する（service_roleはRLSをバイパスするため、check_rate_limit関数からの
-- 内部アクセスには影響しない）。
alter table public.rate_limit_counters enable row level security;
