-- ゲーム詳細画面にスクリーンショット・トレーラーを表示するための試験実装。
-- IGDBのscreenshots/videosフィールドをdetailsアクション取得時にキャッシュする。
alter table public.games
  add column screenshot_urls text[] not null default '{}',
  add column trailer_youtube_id text;
