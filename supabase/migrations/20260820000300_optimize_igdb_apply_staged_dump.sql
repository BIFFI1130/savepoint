-- igdb_apply_staged_dump()は、platforms/genres名の解決とname_ja解決を
-- 行ごとの相関サブクエリで行っていたため、games規模（数十万行）で
-- 極端に遅かった（17分以上経過しても完了せず）。集合演算ベース
-- （unnest+join+group byを全体で1回ずつ）に書き換えて高速化する。

drop function if exists public.igdb_apply_staged_dump();

create or replace function public.igdb_apply_staged_dump()
returns table (staged_count bigint, rows_affected bigint)
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

  if v_prev_success_count is not null and v_staged_count < v_prev_success_count * 0.8 then
    raise exception
      'igdb_stage_games row count % is below 80%% of previous successful run (%)',
      v_staged_count, v_prev_success_count;
  end if;

  with game_platform_names as (
    select sg.id, array_agg(p.name order by p.name) as names
    from public.igdb_stage_games sg
    cross join lateral unnest(coalesce(sg.platforms, '{}'::bigint[])) as pid
    join public.igdb_platforms p on p.id = pid
    group by sg.id
  ),
  game_genre_names as (
    select sg.id, array_agg(gn.name order by gn.name) as names
    from public.igdb_stage_games sg
    cross join lateral unnest(coalesce(sg.genres, '{}'::bigint[])) as gid
    join public.igdb_genres gn on gn.id = gid
    group by sg.id
  ),
  game_ja_names as (
    select distinct on (l.game) l.game as id, l.name
    from public.igdb_stage_game_localizations l
    join public.igdb_regions r on r.id = l.region and r.name = 'Japan'
    where l.name is not null and l.name <> ''
    order by l.game, l.id
  ),
  merged as (
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
      coalesce(gp.names, '{}'::text[]),
      sg.summary,
      sg.url,
      coalesce(gg.names, '{}'::text[]),
      coalesce(sg.themes, '{}'::bigint[]) && array[42]::bigint[],
      ja.name,
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
    left join game_platform_names gp on gp.id = sg.id
    left join game_genre_names gg on gg.id = sg.id
    left join game_ja_names ja on ja.id = sg.id
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

  return query select v_staged_count, v_affected;
end;
$$;

revoke all on function public.igdb_apply_staged_dump() from public;
