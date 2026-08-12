-- ゲームタイトルの日本語表示ロジックを、Google翻訳による機械翻訳から
-- IGDBの公式Localized Title（regionが"Japan"）ベースに変更したため、
-- 旧ルールでキャッシュされたタイトルをすべて破棄する。
-- 次回のsearch/details/weekly_releases取得時に新ルールで再キャッシュされる。
update public.games set name_ja = null;

-- similar_games（jsonb配列）内に埋め込まれているname_jaも同様に破棄する。
-- 空配列（要素0件）の場合はjsonb_aggがnullを返してしまうため、coalesceで元の値
-- （空配列）にフォールバックし、not null制約に抵触しないようにする。
update public.games
set similar_games = coalesce(
  (select jsonb_agg(elem - 'name_ja') from jsonb_array_elements(similar_games) as elem),
  similar_games
)
where similar_games is not null;
