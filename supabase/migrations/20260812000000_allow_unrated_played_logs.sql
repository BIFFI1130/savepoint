-- 「遊んだ」記録でも評価を未入力のまま保存できるようにする。
-- 未評価（rating is null）は星の統計（avg_rating等）には含めない。
alter table public.game_logs
  drop constraint game_logs_rating_required_when_played;
