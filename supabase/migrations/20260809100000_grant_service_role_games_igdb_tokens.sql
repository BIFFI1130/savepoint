-- service_role（igdb-proxy Edge Functionが使用）に、games / igdb_tokens への
-- 書き込み権限が付与されていなかったための修正。
--
-- 「Automatically expose new tables」を無効化した際、authenticatedロール向けの
-- grantは追加したが、service_role向けのgrantを追加し忘れていた。service_roleは
-- RLSをバイパスするが、テーブルへのGRANT自体はRLSとは別物で必要になる。
-- この結果、games テーブルへのキャッシュ書き込みが権限エラーで失敗し
-- （エラーが握りつぶされていたため気づきにくかった）、game_logsへの記録保存時に
-- 外部キー制約違反（games に該当行が存在しない）が発生していた。

grant select, insert, update, delete on public.games to service_role;
grant select, insert, update, delete on public.igdb_tokens to service_role;
