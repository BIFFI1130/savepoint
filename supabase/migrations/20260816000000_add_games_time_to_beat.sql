-- ゲーム詳細画面に表示する「平均クリア時間」。IGDBのgame_time_to_beatsエンドポイント
-- （hastily=急ぎ, normally=通常, completely=完全、いずれも秒単位）から取得し、
-- official_url/summary_jaと同様に詳細取得時にキャッシュする。
alter table public.games
  add column time_to_beat_hastily_seconds integer,
  add column time_to_beat_normally_seconds integer,
  add column time_to_beat_completely_seconds integer;
