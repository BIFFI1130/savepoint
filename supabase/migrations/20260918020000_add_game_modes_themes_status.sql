-- ゲーム詳細画面にゲームモード・テーマ・開発状況バッジを表示するための試験実装。
alter table public.games
  add column game_modes text[] not null default '{}',
  add column themes text[] not null default '{}',
  add column game_status text;
