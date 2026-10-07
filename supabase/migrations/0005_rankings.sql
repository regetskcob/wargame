-- Rating, experience and a history of finished rounds, for the weekly and
-- the all time leaderboard and the statistics per vehicle.

alter table public.scores
  add column rating integer not null default 1000,
  add column xp integer not null default 0;

create table public.round_results (
  id bigint generated always as identity primary key,
  player_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  tank_type smallint not null,
  won boolean not null,
  kills integer not null default 0,
  damage integer not null default 0,
  shots integer not null default 0,
  hits integer not null default 0,
  survival_seconds integer not null default 0,
  opponents integer not null default 0,
  rating_change integer not null default 0,
  xp integer not null default 0,
  created_at timestamptz not null default now()
);

comment on table public.round_results is 'One row per pilot and finished round';

create index round_results_created_at on public.round_results (created_at);
create index round_results_player on public.round_results (player_id);

alter table public.round_results enable row level security;

-- Rows are written only through record_round, which checks them.
create policy "Round results are readable by everyone"
  on public.round_results for select
  using (true);

create view public.weekly_scores
  with (security_invoker = true)
as
select
  r.player_id as id,
  (array_agg(r.name order by r.created_at desc))[1] as name,
  count(*)::integer as rounds,
  (count(*) filter (where r.won))::integer as wins,
  sum(r.kills)::integer as kills,
  sum(r.damage)::integer as damage,
  sum(r.xp)::integer as xp,
  sum(r.rating_change)::integer as rating_change
from public.round_results r
where r.created_at >= date_trunc('week', now())
group by r.player_id;

comment on view public.weekly_scores is 'Totals per pilot since Monday';

create view public.tank_scores
  with (security_invoker = true)
as
select
  r.player_id,
  r.tank_type,
  count(*)::integer as rounds,
  (count(*) filter (where r.won))::integer as wins,
  sum(r.kills)::integer as kills,
  sum(r.damage)::integer as damage,
  sum(r.shots)::integer as shots,
  sum(r.hits)::integer as hits
from public.round_results r
group by r.player_id, r.tank_type;

comment on view public.tank_scores is 'Totals per pilot and vehicle';

-- Records a finished round for the signed in pilot: adds it to the totals,
-- grants experience and moves the Elo rating against the human opponents the
-- pilot outlasted (p_beaten) or fell before (p_beaten_by). The numbers are
-- clamped to what a round allows, and a pilot can record at most one round
-- every few seconds.
create function public.record_round(
  p_name text,
  p_tank smallint,
  p_won boolean,
  p_kills integer,
  p_damage integer,
  p_shots integer,
  p_hits integer,
  p_survival integer,
  p_beaten uuid[] default '{}',
  p_beaten_by uuid[] default '{}'
)
returns table (rating integer, rating_change integer, xp integer, xp_gained integer)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  me uuid := auth.uid();
  v_name text := left(coalesce(nullif(trim(p_name), ''), 'Panzer'), 16);
  v_kills integer := least(greatest(coalesce(p_kills, 0), 0), 15);
  v_damage integer := least(greatest(coalesce(p_damage, 0), 0), 5000);
  v_shots integer := least(greatest(coalesce(p_shots, 0), 0), 3000);
  v_hits integer;
  v_survival integer := least(greatest(coalesce(p_survival, 0), 0), 1800);
  v_rating integer;
  v_opponents integer := 0;
  v_actual double precision := 0;
  v_expected double precision := 0;
  v_change integer := 0;
  v_gained integer;
begin
  if me is null then
    raise exception 'not signed in';
  end if;
  if exists (
    select 1 from public.round_results r
    where r.player_id = me and r.created_at > now() - interval '8 seconds'
  ) then
    raise exception 'round recorded too soon after the last one';
  end if;
  v_hits := least(greatest(coalesce(p_hits, 0), 0), v_shots);

  insert into public.scores as s (id, name)
  values (me, v_name)
  on conflict (id) do nothing;
  select s.rating into v_rating from public.scores s where s.id = me for update;

  with opponents as (
    select distinct b as id, 1.0 as score
    from unnest(coalesce(p_beaten, '{}')) b
    where b <> me
    union
    select distinct b, 0.0
    from unnest(coalesce(p_beaten_by, '{}')) b
    where b <> me
  )
  select
    count(*),
    coalesce(sum(o.score), 0),
    coalesce(
      sum(1.0 / (1 + power(10, (coalesce(s.rating, 1000) - v_rating) / 400.0))),
      0
    )
  into v_opponents, v_actual, v_expected
  from opponents o
  left join public.scores s on s.id = o.id;

  if v_opponents > 0 then
    v_change := round(32.0 * (v_actual - v_expected) / v_opponents);
  end if;
  v_gained := 10 + 20 * v_kills + (case when p_won then 50 else 0 end)
    + least(v_damage, 2000) / 10;

  update public.scores s set
    name = v_name,
    wins = s.wins + (case when p_won then 1 else 0 end),
    rounds = s.rounds + 1,
    kills = s.kills + v_kills,
    damage = s.damage + v_damage,
    shots = s.shots + v_shots,
    hits = s.hits + v_hits,
    survival_seconds = s.survival_seconds + v_survival,
    xp = s.xp + v_gained,
    rating = greatest(100, s.rating + v_change),
    updated_at = now()
  where s.id = me;

  insert into public.round_results (
    player_id, name, tank_type, won, kills, damage, shots, hits,
    survival_seconds, opponents, rating_change, xp
  ) values (
    me, v_name, greatest(0, least(p_tank, 50)), p_won, v_kills, v_damage,
    v_shots, v_hits, v_survival, v_opponents, v_change, v_gained
  );

  return query
    select s.rating, v_change, s.xp, v_gained
    from public.scores s where s.id = me;
end;
$$;

revoke execute on function public.record_round from public, anon;
grant execute on function public.record_round to authenticated;
