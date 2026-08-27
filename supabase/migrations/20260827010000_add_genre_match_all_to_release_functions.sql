-- ジャンル絞り込みで複数選択した場合の判定を「いずれかが当てはまる」（OR、既定）
-- 「すべて当てはまる」（AND）から選べるようにする。p_match_all_genresを末尾に
-- 追加パラメータ（デフォルトfalse）として足すのみで、既存の呼び出し元（省略時）の
-- 挙動は変わらない。

create or replace function public.igdb_weekly_releases(
  p_platforms text[] default '{}',
  p_genres text[] default '{}',
  p_include_adult boolean default false,
  p_include_indie boolean default false,
  p_match_all_genres boolean default false
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
    and (
      p_genres = '{}'
      or (p_match_all_genres and g.genres @> p_genres)
      or (not p_match_all_genres and g.genres && p_genres)
    )
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
  p_include_indie boolean default false,
  p_match_all_genres boolean default false
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
    and (
      p_genres = '{}'
      or (p_match_all_genres and g.genres @> p_genres)
      or (not p_match_all_genres and g.genres && p_genres)
    )
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
  p_include_indie boolean default false,
  p_match_all_genres boolean default false
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
    and (
      p_genres = '{}'
      or (p_match_all_genres and g.genres @> p_genres)
      or (not p_match_all_genres and g.genres && p_genres)
    )
    and (p_include_adult or not (g.theme_ids && array[42]::bigint[]))
    and (p_include_indie or not ('Indie' = any(g.genres)))
    and g.version_parent_id is null
    and (g.game_type_id is null or g.game_type_id = any(array[0, 2, 8, 10]::bigint[]))
    and not (g.keyword_ids && array[2004, 16696, 24124]::bigint[])
  order by g.total_rating_count desc nulls last, g.id desc
  limit 500;
$$;

create or replace function public.igdb_top100(
  p_platforms text[] default '{}',
  p_genres text[] default '{}',
  p_include_adult boolean default false,
  p_include_indie boolean default false,
  p_match_all_genres boolean default false
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
      and (
        p_genres = '{}'
        or (p_match_all_genres and g.genres @> p_genres)
        or (not p_match_all_genres and g.genres && p_genres)
      )
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

grant execute on function public.igdb_weekly_releases(text[], text[], boolean, boolean, boolean) to authenticated;
grant execute on function public.igdb_monthly_releases(text[], text[], boolean, boolean, boolean) to authenticated;
grant execute on function public.igdb_calendar_releases(date, integer, text[], text[], boolean, boolean, boolean) to authenticated;
grant execute on function public.igdb_top100(text[], text[], boolean, boolean, boolean) to authenticated;
