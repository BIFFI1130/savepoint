-- Postgresの関数は作成時、デフォルトでPUBLIC（anonロールも含む）にEXECUTE権限が
-- 付与される。20260820000000でauthenticatedへのgrantは行ったが、PUBLICからの
-- revokeを忘れていたため、実際にはanon keyだけでも呼び出せてしまっていた
-- （サインアップ前のユーザーでもIGDBミラーを閲覧できる状態）。明示的に絞る。

revoke all on function public.igdb_weekly_releases(text[], text[], boolean, boolean) from public;
revoke all on function public.igdb_monthly_releases(text[], text[], boolean, boolean) from public;
revoke all on function public.igdb_calendar_releases(date, integer, text[], text[], boolean, boolean) from public;
revoke all on function public.igdb_top100(text[], text[], boolean, boolean) from public;
revoke all on function public.igdb_dump_last_success() from public;

grant execute on function public.igdb_weekly_releases(text[], text[], boolean, boolean) to authenticated;
grant execute on function public.igdb_monthly_releases(text[], text[], boolean, boolean) to authenticated;
grant execute on function public.igdb_calendar_releases(date, integer, text[], text[], boolean, boolean) to authenticated;
grant execute on function public.igdb_top100(text[], text[], boolean, boolean) to authenticated;
grant execute on function public.igdb_dump_last_success() to authenticated;
