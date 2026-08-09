-- ゲーム詳細情報の拡充（企業情報・関連作品・日本語翻訳キャッシュ）と、
-- 記録の「遊んだ/遊びたい」ステータス・ネタバレタグ対応。

alter table public.games
  add column developers text[] not null default '{}',
  add column publishers text[] not null default '{}',
  add column similar_games jsonb not null default '[]',
  add column summary_ja text;

alter table public.game_logs
  add column status text not null default 'played' check (status in ('played', 'want_to_play')),
  add column has_spoiler boolean not null default false;

-- 「遊びたい」は未プレイのため評価なしで記録できるようにする。
alter table public.game_logs alter column rating drop not null;

-- ただし「遊んだ」を選んだ記録には評価を必須のままにする。
alter table public.game_logs
  add constraint game_logs_rating_required_when_played
  check (status = 'want_to_play' or rating is not null);
