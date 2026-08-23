-- profilesテーブルは検索・フォロー一覧等で他ユーザーの行も読めるよう
-- `profiles_select_authenticated`（using (true)）で全行SELECTを許可しているが、
-- これはRLS（行単位）であって列単位の制限ではないため、クライアントが`select('*')`
-- （PostgREST既定）で問い合わせると、本来自分専用であるべき列
-- （birth_year・birth_month＝年齢確認用、game_history・favorite_genres＝
-- プロフィール編集用の自由記述）まで他ユーザーに丸ごと露出してしまっていた。
-- Flutter側のクエリを必要な列だけに絞る対応と合わせて、それをバイパスして
-- REST APIを直接叩かれた場合にも安全なよう、DB側でも他ユーザー閲覧用の経路を
-- 安全な列だけを持つビュー（favorite_games_feed・follow_feedと同じ設計）に限定する。

create view public.profiles_public as
select
  id,
  username,
  display_name,
  avatar_url,
  is_public,
  created_at
from public.profiles;

grant select on public.profiles_public to authenticated;

-- 直接のprofilesテーブルへのSELECTは本人の行のみに制限する。
-- INSERT/UPDATEポリシーは元々本人のみのため変更不要。
drop policy "profiles_select_authenticated" on public.profiles;

create policy "profiles_select_own"
  on public.profiles for select
  to authenticated
  using (auth.uid() = id);
