-- 個々のレビュー内容やuser_idは非公開のまま、ゲームごとの「遊んだ／遊びたい」件数だけを
-- 集計して公開するビュー。トレンド画面・ゲーム詳細の統計表示に使う。
--
-- このビューはマイグレーション実行ロール（BYPASSRLS属性を持つ）が所有するため、
-- game_logsのRLS（本人の行しか見えない制限）を経由せず全ユーザー分を集計できる。
-- ビュー自体が公開するのは件数の合計のみで、誰がどう記録したかは一切含まれない。
create view public.game_log_stats as
select
  g.id as game_id,
  g.name,
  g.cover_url,
  count(*) filter (where gl.status = 'played') as played_count,
  count(*) filter (where gl.status = 'want_to_play') as want_to_play_count
from public.game_logs gl
join public.games g on g.id = gl.game_id
group by g.id, g.name, g.cover_url;

grant select on public.game_log_stats to authenticated;
