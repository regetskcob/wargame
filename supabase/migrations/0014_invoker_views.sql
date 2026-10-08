-- The security advisor flags weekly_scores and tank_scores, which 0011 made
-- run with the rights of their owner so they could read past the policies
-- of round_results. Both run with the rights of the caller again:
--
-- * tank_scores is only read for the own pilot, and the own rows are
--   readable anyway. It no longer shows other pilots' totals per vehicle.
-- * weekly_scores needs every pilot's rows. It reads them through a
--   function in a schema the API does not expose, which hands out the same
--   totals as before and nothing more.

alter view public.tank_scores set (security_invoker = true);

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to anon, authenticated;

create function private.weekly_scores()
returns table (
  id uuid,
  name text,
  rounds integer,
  wins integer,
  kills integer,
  damage integer,
  xp integer,
  rating_change integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    r.player_id,
    (array_agg(r.name order by r.created_at desc))[1],
    count(*)::integer,
    (count(*) filter (where r.won))::integer,
    sum(r.kills)::integer,
    sum(r.damage)::integer,
    sum(r.xp)::integer,
    sum(r.rating_change)::integer
  from public.round_results r
  where r.created_at >= date_trunc('week', now())
    and public.is_account(r.player_id)
  group by r.player_id;
$$;

revoke execute on function private.weekly_scores from public;
grant execute on function private.weekly_scores to anon, authenticated;

create or replace view public.weekly_scores
  with (security_invoker = true)
as
select * from private.weekly_scores();

comment on view public.weekly_scores is 'Totals per pilot since Monday';
