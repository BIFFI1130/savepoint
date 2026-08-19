-- igdb_apply_staged_dump()のマージ処理で使う結合キーにインデックスを追加し、
-- games.cover=covers.id、game_localizations.game/regionでの結合を高速化する。
-- ステージングテーブルは毎回TRUNCATEされるがインデックス構造自体は残る。

create index igdb_stage_covers_id_idx on public.igdb_stage_covers (id);
create index igdb_stage_game_localizations_game_region_idx
  on public.igdb_stage_game_localizations (game, region);
