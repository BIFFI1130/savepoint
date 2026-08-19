-- IGDB Data Dumps（Data Partner限定機能。games/covers/platforms/genres/
-- game_localizations/regionsを日次CSVで一括取得できる）を取り込んでローカルに
-- ミラーし、絞り込みのみで自由文検索を伴わない4つの読み取り経路（今週/今月発売・
-- TOP100・発売日カレンダー）を、igdb-proxy Edge Function経由のライブIGDB問い合わせ
-- なしで返せるようにする。自由文検索（search）・ゲーム詳細（details、Google翻訳や
-- 類似ゲーム等のエンリッチメントを伴う）は対象外で、igdb-proxyのまま維持する。
--
-- 取り込みジョブ（tools/igdb_dump_ingest、このマイグレーションの範囲外）は、
-- 各エンドポイントのCSVをこのファイルで定義するステージングテーブルへCOPYし、
-- 最後に igdb_apply_staged_dump() を1回呼ぶことで、1トランザクションでの
-- アトミックなマージを行う。
--
-- クライアント（Flutter）からは games テーブルを直接SELECTさせない。
-- games_select_all（authenticated全件SELECT可）ポリシーは既に存在するが、
-- ローカル読み取りに切り替えるとこれが本格稼働してしまい、APKから取り出せる
-- anon keyだけで誰でもIGDBミラーを丸ごとページングできてしまう。代わりに、
-- 固定シェイプ・件数上限を強制できるSECURITY DEFINER関数（RPC）として公開する。

-- ============================================================
-- 1. games テーブルの拡張
-- ============================================================

alter table public.games
  add column rating double precision,
  add column rating_count integer,
  add column total_rating_count integer,
  add column theme_ids bigint[] not null default '{}',
  add column keyword_ids bigint[] not null default '{}',
  add column game_type_id bigint,
  add column version_parent_id bigint,
  -- ダンプ取り込みで最後に書き込まれた時刻。search/detailsのライブ経路だけで
  -- 書き込まれた行はNULLのままになる（theme_ids等の除外フィルタ用カラムも
  -- 未検証のため）。RPC側でこれがNULLの行を除外し、ライブ経路由来のDLC/成人向け
  -- 等が未フィルタのまま一覧に紛れ込むのを防ぐ。
  add column dump_synced_at timestamptz;

create index games_platforms_gin_idx on public.games using gin (platforms);
create index games_genres_gin_idx on public.games using gin (genres);
create index games_theme_ids_gin_idx on public.games using gin (theme_ids);
create index games_keyword_ids_gin_idx on public.games using gin (keyword_ids);
create index games_first_release_date_idx on public.games (first_release_date);
create index games_total_rating_count_idx on public.games (total_rating_count);
create index games_rating_count_idx on public.games (rating_count);
create index games_dump_synced_at_idx on public.games (dump_synced_at);

-- ============================================================
-- 2. ルックアップテーブル（id→name解決専用。クライアント非公開）
-- ============================================================
-- 取り込みのたびにTRUNCATE＋COPYで全件洗い替えする小さなテーブル。
-- 「Automatically expose new tables」はプロジェクト設定で無効化されているため、
-- grantしない限りData API経由では到達不可能。

create table public.igdb_platforms (
  id bigint primary key,
  name text not null
);

create table public.igdb_genres (
  id bigint primary key,
  name text not null
);

create table public.igdb_regions (
  id bigint primary key,
  name text not null
);

-- ============================================================
-- 3. ステージングテーブル（CSVをCOPYで流し込む先。クライアント非公開）
-- ============================================================
-- first_release_dateはtimestamptzではなくtimestamp（タイムゾーン無し）にする。
-- ダンプのTIMESTAMP列はUTCのnaive値のため、timestamptzにするとCOPY実行時の
-- セッションタイムゾーンに依存した解釈が入り込む余地があり、事故りやすい。
-- 取り込みスクリプト側はこのテーブルへCOPYする接続でタイムゾーンをUTCに
-- 固定すること。

create table public.igdb_stage_games (
  id bigint,
  name text,
  summary text,
  url text,
  cover bigint,
  platforms bigint[],
  genres bigint[],
  themes bigint[],
  keywords bigint[],
  game_type bigint,
  version_parent bigint,
  first_release_date timestamp,
  rating double precision,
  rating_count integer,
  total_rating_count integer
);

create table public.igdb_stage_covers (
  id bigint,
  image_id text,
  game bigint
);

create table public.igdb_stage_game_localizations (
  id bigint,
  name text,
  game bigint,
  region bigint
);

-- ============================================================
-- 4. 取り込み実行ログ
-- ============================================================

create table public.igdb_dump_runs (
  id bigint generated always as identity primary key,
  endpoint text not null,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null default 'running' check (status in ('running', 'success', 'failed')),
  row_count integer,
  error text
);

create index igdb_dump_runs_endpoint_status_idx on public.igdb_dump_runs (endpoint, status, finished_at desc);

-- ============================================================
-- 5. マージ関数: ステージング済みデータをgamesへアトミックに反映
-- ============================================================
-- 詳細画面専用カラム（summary_ja・developers・publishers・similar_games・
-- official_url・is_japanese_developer・time_to_beat_*）はSET句に一切
-- 含めないことで、igdb-proxyのdetailsアクションが書き込んだ値を上書きしない
-- ことをSQLレベルで保証する。
--
-- 呼び出し側（取り込みスクリプト）が igdb_platforms / igdb_genres / igdb_regions /
-- igdb_stage_games / igdb_stage_covers / igdb_stage_game_localizations への
-- TRUNCATE + COPYを終えた後、この関数を1回呼ぶ。

create or replace function public.igdb_apply_staged_dump()
returns table (rows_affected bigint)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_staged_count bigint;
  v_prev_success_count integer;
  v_affected bigint;
begin
  select count(*) into v_staged_count from public.igdb_stage_games;

  select row_count into v_prev_success_count
    from public.igdb_dump_runs
    where endpoint = 'games' and status = 'success'
    order by finished_at desc
    limit 1;

  -- ガード: 前回成功時の行数の80%を下回ったら中断する
  -- （ダウンロード欠損の検知。無言でカタログの大半を消してしまう事故を防ぐ）
  if v_prev_success_count is not null and v_staged_count < v_prev_success_count * 0.8 then
    raise exception
      'igdb_stage_games row count % is below 80%% of previous successful run (%)',
      v_staged_count, v_prev_success_count;
  end if;

  with merged as (
    insert into public.games as g (
      id, name, cover_url, first_release_date, platforms, summary, igdb_url, genres,
      is_adult, name_ja, rating, rating_count, total_rating_count,
      theme_ids, keyword_ids, game_type_id, version_parent_id, dump_synced_at, cached_at
    )
    select
      sg.id,
      coalesce(sg.name, '(タイトル不明)'),
      case
        when c.image_id is not null
          then 'https://images.igdb.com/igdb/image/upload/t_cover_big/' || c.image_id || '.jpg'
        else null
      end,
      sg.first_release_date::date,
      coalesce(
        (select array_agg(p.name order by p.name)
           from unnest(coalesce(sg.platforms, '{}'::bigint[])) as pid
           join public.igdb_platforms p on p.id = pid),
        '{}'::text[]
      ),
      sg.summary,
      sg.url,
      coalesce(
        (select array_agg(gn.name order by gn.name)
           from unnest(coalesce(sg.genres, '{}'::bigint[])) as gid
           join public.igdb_genres gn on gn.id = gid),
        '{}'::text[]
      ),
      coalesce(sg.themes, '{}'::bigint[]) && array[42]::bigint[],
      (
        select l.name
          from public.igdb_stage_game_localizations l
          join public.igdb_regions r on r.id = l.region and r.name = 'Japan'
          where l.game = sg.id and l.name is not null and l.name <> ''
          limit 1
      ),
      sg.rating,
      sg.rating_count,
      sg.total_rating_count,
      coalesce(sg.themes, '{}'::bigint[]),
      coalesce(sg.keywords, '{}'::bigint[]),
      sg.game_type,
      sg.version_parent,
      now(),
      now()
    from public.igdb_stage_games sg
    left join public.igdb_stage_covers c on c.id = sg.cover
    on conflict (id) do update set
      name = excluded.name,
      cover_url = excluded.cover_url,
      first_release_date = excluded.first_release_date,
      platforms = excluded.platforms,
      summary = excluded.summary,
      igdb_url = excluded.igdb_url,
      genres = excluded.genres,
      is_adult = excluded.is_adult,
      name_ja = excluded.name_ja,
      rating = excluded.rating,
      rating_count = excluded.rating_count,
      total_rating_count = excluded.total_rating_count,
      theme_ids = excluded.theme_ids,
      keyword_ids = excluded.keyword_ids,
      game_type_id = excluded.game_type_id,
      version_parent_id = excluded.version_parent_id,
      dump_synced_at = excluded.dump_synced_at
      -- cached_atは既存のigdb-proxy検索キャッシュ用の意味を保つため更新しない
    where
      (g.name, g.cover_url, g.first_release_date, g.platforms, g.summary, g.igdb_url,
       g.genres, g.is_adult, g.name_ja, g.rating, g.rating_count, g.total_rating_count,
       g.theme_ids, g.keyword_ids, g.game_type_id, g.version_parent_id)
      is distinct from
      (excluded.name, excluded.cover_url, excluded.first_release_date, excluded.platforms,
       excluded.summary, excluded.igdb_url, excluded.genres, excluded.is_adult,
       excluded.name_ja, excluded.rating, excluded.rating_count, excluded.total_rating_count,
       excluded.theme_ids, excluded.keyword_ids, excluded.game_type_id, excluded.version_parent_id)
    returning 1
  )
  select count(*) into v_affected from merged;

  return query select v_affected;
end;
$$;

revoke all on function public.igdb_apply_staged_dump() from public;

-- ============================================================
-- 6. 読み取りRPC（クライアント公開。固定シェイプ・件数上限を強制する）
-- ============================================================
-- 除外フィルタの定数はigdb-proxy/index.tsのcommonExclusionFiltersと同一:
--   ADULT_THEME_ID=42, INDIE_GENRE_ID=32(→genres名'Indie'で判定),
--   ALLOWED_GAME_TYPE_IDS=(0,2,8,10), UNOFFICIAL_KEYWORD_IDS=(2004,16696,24124)
-- dump_synced_at is not null で、ライブ経路(search/details)だけで書き込まれた
-- 未検証の行（除外フィルタ用カラムが空のまま）が紛れ込まないようにする。

create or replace function public.igdb_weekly_releases(
  p_platforms text[] default '{}',
  p_genres text[] default '{}',
  p_include_adult boolean default false,
  p_include_indie boolean default false
)
returns table (
  id bigint, name text, name_ja text, cover_url text, first_release_date date,
  platforms text[], summary text, summary_ja text, igdb_url text, genres text[],
  is_adult boolean, is_japanese_developer boolean, developers text[], publishers text[],
  similar_games jsonb, official_url text,
  time_to_beat_hastily_seconds integer, time_to_beat_normally_seconds integer,
  time_to_beat_completely_seconds integer
)
language sql
security definer
stable
set search_path = public
as $$
  select
    g.id, g.name, g.name_ja, g.cover_url, g.first_release_date,
    g.platforms, g.summary, g.summary_ja, g.igdb_url, g.genres,
    g.is_adult, g.is_japanese_developer, g.developers, g.publishers,
    g.similar_games, g.official_url,
    g.time_to_beat_hastily_seconds, g.time_to_beat_normally_seconds, g.time_to_beat_completely_seconds
  from public.games g
  where g.dump_synced_at is not null
    and g.first_release_date >= date_trunc('week', (now() at time zone 'utc'))::date
    and g.first_release_date < (date_trunc('week', (now() at time zone 'utc'))::date + 7)
    and (p_platforms = '{}' or g.platforms && p_platforms)
    and (p_genres = '{}' or g.genres && p_genres)
    and (p_include_adult or not (g.theme_ids && array[42]::bigint[]))
    and (p_include_indie or not ('Indie' = any(g.genres)))
    and g.version_parent_id is null
    and (g.game_type_id is null or g.game_type_id = any(array[0, 2, 8, 10]::bigint[]))
    and not (g.keyword_ids && array[2004, 16696, 24124]::bigint[])
  order by g.total_rating_count desc nulls last, g.id desc
  limit 30;
$$;

create or replace function public.igdb_monthly_releases(
  p_platforms text[] default '{}',
  p_genres text[] default '{}',
  p_include_adult boolean default false,
  p_include_indie boolean default false
)
returns table (
  id bigint, name text, name_ja text, cover_url text, first_release_date date,
  platforms text[], summary text, summary_ja text, igdb_url text, genres text[],
  is_adult boolean, is_japanese_developer boolean, developers text[], publishers text[],
  similar_games jsonb, official_url text,
  time_to_beat_hastily_seconds integer, time_to_beat_normally_seconds integer,
  time_to_beat_completely_seconds integer
)
language sql
security definer
stable
set search_path = public
as $$
  select
    g.id, g.name, g.name_ja, g.cover_url, g.first_release_date,
    g.platforms, g.summary, g.summary_ja, g.igdb_url, g.genres,
    g.is_adult, g.is_japanese_developer, g.developers, g.publishers,
    g.similar_games, g.official_url,
    g.time_to_beat_hastily_seconds, g.time_to_beat_normally_seconds, g.time_to_beat_completely_seconds
  from public.games g
  where g.dump_synced_at is not null
    and g.first_release_date >= date_trunc('month', (now() at time zone 'utc'))::date
    and g.first_release_date < (date_trunc('month', (now() at time zone 'utc'))::date + interval '1 month')::date
    and (p_platforms = '{}' or g.platforms && p_platforms)
    and (p_genres = '{}' or g.genres && p_genres)
    and (p_include_adult or not (g.theme_ids && array[42]::bigint[]))
    and (p_include_indie or not ('Indie' = any(g.genres)))
    and g.version_parent_id is null
    and (g.game_type_id is null or g.game_type_id = any(array[0, 2, 8, 10]::bigint[]))
    and not (g.keyword_ids && array[2004, 16696, 24124]::bigint[])
  order by g.total_rating_count desc nulls last, g.id desc
  limit 60;
$$;

create or replace function public.igdb_calendar_releases(
  p_range_start date,
  p_days integer,
  p_platforms text[] default '{}',
  p_genres text[] default '{}',
  p_include_adult boolean default false,
  p_include_indie boolean default false
)
returns table (
  id bigint, name text, name_ja text, cover_url text, first_release_date date,
  platforms text[], summary text, summary_ja text, igdb_url text, genres text[],
  is_adult boolean, is_japanese_developer boolean, developers text[], publishers text[],
  similar_games jsonb, official_url text,
  time_to_beat_hastily_seconds integer, time_to_beat_normally_seconds integer,
  time_to_beat_completely_seconds integer
)
language sql
security definer
stable
set search_path = public
as $$
  select
    g.id, g.name, g.name_ja, g.cover_url, g.first_release_date,
    g.platforms, g.summary, g.summary_ja, g.igdb_url, g.genres,
    g.is_adult, g.is_japanese_developer, g.developers, g.publishers,
    g.similar_games, g.official_url,
    g.time_to_beat_hastily_seconds, g.time_to_beat_normally_seconds, g.time_to_beat_completely_seconds
  from public.games g
  where g.dump_synced_at is not null
    and g.first_release_date >= p_range_start
    and g.first_release_date < p_range_start + p_days
    and (p_platforms = '{}' or g.platforms && p_platforms)
    and (p_genres = '{}' or g.genres && p_genres)
    and (p_include_adult or not (g.theme_ids && array[42]::bigint[]))
    and (p_include_indie or not ('Indie' = any(g.genres)))
    and g.version_parent_id is null
    and (g.game_type_id is null or g.game_type_id = any(array[0, 2, 8, 10]::bigint[]))
    and not (g.keyword_ids && array[2004, 16696, 24124]::bigint[])
  order by g.total_rating_count desc nulls last, g.id desc
  limit 500;
$$;

-- top100は候補プール内（rating_count>=200、最大500件）での平均評価をもとにした
-- ベイズ加重評価（IMDb方式）でランキングする。igdb-proxyのtop100アクションと
-- 同じアルゴリズムをそのまま再現している（母集団や平均が変わると順位も変わる
-- ため、事前計算した固定スコアではなく都度計算する）。
create or replace function public.igdb_top100(
  p_platforms text[] default '{}',
  p_genres text[] default '{}',
  p_include_adult boolean default false,
  p_include_indie boolean default false
)
returns table (
  id bigint, name text, name_ja text, cover_url text, first_release_date date,
  platforms text[], summary text, summary_ja text, igdb_url text, genres text[],
  is_adult boolean, is_japanese_developer boolean, developers text[], publishers text[],
  similar_games jsonb, official_url text,
  time_to_beat_hastily_seconds integer, time_to_beat_normally_seconds integer,
  time_to_beat_completely_seconds integer
)
language sql
security definer
stable
set search_path = public
as $$
  with pool as (
    select g.id, g.rating, g.rating_count
    from public.games g
    where g.dump_synced_at is not null
      and g.rating is not null
      and g.rating_count >= 200
      and (p_platforms = '{}' or g.platforms && p_platforms)
      and (p_genres = '{}' or g.genres && p_genres)
      and (p_include_adult or not (g.theme_ids && array[42]::bigint[]))
      and (p_include_indie or not ('Indie' = any(g.genres)))
      and g.version_parent_id is null
      and (g.game_type_id is null or g.game_type_id = any(array[0, 2, 8, 10]::bigint[]))
      and not (g.keyword_ids && array[2004, 16696, 24124]::bigint[])
    order by g.rating_count desc, g.id desc
    limit 500
  ),
  stats as (
    select avg(rating) as mean_rating from pool
  )
  select
    g.id, g.name, g.name_ja, g.cover_url, g.first_release_date,
    g.platforms, g.summary, g.summary_ja, g.igdb_url, g.genres,
    g.is_adult, g.is_japanese_developer, g.developers, g.publishers,
    g.similar_games, g.official_url,
    g.time_to_beat_hastily_seconds, g.time_to_beat_normally_seconds, g.time_to_beat_completely_seconds
  from pool p
  join public.games g on g.id = p.id
  cross join stats s
  order by
    ((p.rating_count::double precision / (p.rating_count + 200)) * p.rating
      + (200.0 / (p.rating_count + 200)) * s.mean_rating) desc,
    p.id desc
  limit 100;
$$;

grant execute on function public.igdb_weekly_releases(text[], text[], boolean, boolean) to authenticated;
grant execute on function public.igdb_monthly_releases(text[], text[], boolean, boolean) to authenticated;
grant execute on function public.igdb_calendar_releases(date, integer, text[], text[], boolean, boolean) to authenticated;
grant execute on function public.igdb_top100(text[], text[], boolean, boolean) to authenticated;

-- クライアント側の鮮度チェック用。取り込みが止まっていても画面が無言で空に
-- ならないよう、最後に成功した取り込み時刻をアプリ側で確認し、一定時間
-- （48時間目安）より古ければライブ経路（IgdbRepository）へフォールバックする。
create or replace function public.igdb_dump_last_success()
returns timestamptz
language sql
security definer
stable
set search_path = public
as $$
  select max(finished_at)
  from public.igdb_dump_runs
  where endpoint = 'games' and status = 'success';
$$;

grant execute on function public.igdb_dump_last_success() to authenticated;
