-- プロフィールの公開設定のデフォルトを非公開から全公開に変更する。
--
-- 個別のレビュー投稿（game_logs.visibility）は元々デフォルトで「全公開」に
-- なっている（log_review_screen.dartのUI側）が、プロフィール側の公開設定
-- （profile_visibility）はデフォルト「非公開」だったため、二重のゲートにより
-- 「レビューは公開設定のはずなのに、プロフィールが非公開なせいで誰にも
-- 見えていない」という、ユーザーが気づきにくいねじれた初期状態になっていた。
--
-- new.idのみを渡すhandle_new_user()トリガー（20260809000000_init_schema.sql）
-- がprofilesへの新規行挿入をこのカラムのデフォルト値に任せているため、
-- ここでデフォルト値だけを変更すれば新規登録ユーザーにのみ適用され、
-- 既存ユーザーの設定（明示的に保存済みの値）には一切影響しない。
alter table public.profiles
  alter column profile_visibility set default 'public';
