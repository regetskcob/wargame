-- Experience for outlasting. Until now a lost round paid the same no matter
-- how long the pilot held out: 10 for the round plus kills and damage, so
-- going down second to last earned exactly what going down first did. The
-- rating already counted the order of the fall pairwise, but by a few
-- points only, and the experience is what the end screen shows first. Now
-- every opponent the pilot outlasted (people and CPU tanks, in a team
-- round the beaten team) pays 10 experience, so holding out shows.
--
-- Same parameters and result as in 0011, only the experience changed.
create or replace function public.record_round(
  p_name text,
  p_tank smallint,
  p_won boolean,
  p_kills integer,
  p_damage integer,
  p_shots integer,
  p_hits integer,
  p_survival integer,
  p_beaten uuid[] default '{}',
  p_beaten_by uuid[] default '{}',
  p_cpu_beaten integer default 0,
  p_cpu_beaten_by integer default 0,
  p_cpu_rating integer default 1000
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
  v_last timestamptz;
  v_rating integer;
  v_opponents integer := 0;
  v_actual double precision := 0;
  v_expected double precision := 0;
  v_change integer := 0;
  v_gained integer;
  v_cpu_beaten integer := least(greatest(coalesce(p_cpu_beaten, 0), 0), 8);
  v_cpu_beaten_by integer := least(greatest(coalesce(p_cpu_beaten_by, 0), 0), 8);
  v_cpu_rating integer := least(greatest(coalesce(p_cpu_rating, 1000), 800), 1200);
  v_cpu_expected double precision;
begin
  if me is null then
    raise exception 'not signed in';
  end if;
  -- One call per pilot at a time, so parallel calls cannot all pass the
  -- checks below before the first one is written.
  perform pg_advisory_xact_lock(hashtextextended(me::text, 11));

  select max(r.created_at) into v_last
  from public.round_results r where r.player_id = me;
  if v_last > now() - interval '8 seconds' then
    raise exception 'round recorded too soon after the last one';
  end if;
  if (
    select count(*) from public.round_results r
    where r.player_id = me and r.created_at > now() - interval '1 hour'
  ) >= 60 then
    raise exception 'too many rounds in the last hour';
  end if;
  -- Nobody survives longer than the time since the last recorded round.
  if v_last is not null then
    v_survival := least(
      v_survival,
      ceil(extract(epoch from now() - v_last))::integer
    );
  end if;
  v_hits := least(greatest(coalesce(p_hits, 0), 0), v_shots);

  insert into public.scores as s (id, name)
  values (me, v_name)
  on conflict (id) do nothing;
  select s.rating into v_rating from public.scores s where s.id = me for update;

  -- Only real accounts count as opponents, at most eight each way, as many
  -- as a full room holds.
  with beaten as (
    select distinct b as id from unnest(coalesce(p_beaten, '{}')) b
    where b <> me and exists (select 1 from auth.users u where u.id = b)
    limit 8
  ), beaten_by as (
    select distinct b as id from unnest(coalesce(p_beaten_by, '{}')) b
    where b <> me and exists (select 1 from auth.users u where u.id = b)
    limit 8
  ), opponents as (
    select id, 1.0 as score from beaten
    union
    select id, 0.0 from beaten_by
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

  -- CPU tanks count as opponents with a fixed rating for their level.
  v_cpu_expected := 1.0 / (1 + power(10, (v_cpu_rating - v_rating) / 400.0));
  v_opponents := v_opponents + v_cpu_beaten + v_cpu_beaten_by;
  v_actual := v_actual + v_cpu_beaten;
  v_expected := v_expected + (v_cpu_beaten + v_cpu_beaten_by) * v_cpu_expected;

  if v_opponents > 0 then
    v_change := round(32.0 * (v_actual - v_expected) / v_opponents);
  end if;
  v_gained := 10 + 20 * v_kills + (case when p_won then 50 else 0 end)
    + least(v_damage, 2000) / 10
    -- Opponents outlasted: the rated ones and the CPU tanks, at most 16.
    + 10 * round(v_actual)::integer;

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
