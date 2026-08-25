-- サブスク特典「推しゲー登録数の上限撤廃」。DB側の安全弁（5件固定）を50件に緩和する。
-- 実際の無料/課金の区別はクライアント側のUIで行う（このアプリの他のサブスク特典と
-- 同じ方針：DBのサブスク状態同期は行わず、entitlement判定はRevenueCat SDK経由で
-- クライアントのみが把握する）。50件は「実質無制限」だが、誤操作やAPI直叩きによる
-- 際限の無い登録を防ぐための上限として残す。
create or replace function public.check_favorite_games_limit()
returns trigger
language plpgsql
as $$
begin
  if (select count(*) from public.favorite_games where user_id = new.user_id) >= 50 then
    raise exception 'favorite_games: 登録できるのは最大50件までです';
  end if;
  return new;
end;
$$;
