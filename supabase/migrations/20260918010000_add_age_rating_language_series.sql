-- ゲーム詳細画面に年齢レーティング・対応言語一覧・シリーズ作品を表示するための試験実装。
alter table public.games
  add column age_rating_organization text,
  add column age_rating_value text,
  add column language_supports jsonb not null default '[]',
  add column series_games jsonb not null default '[]';
