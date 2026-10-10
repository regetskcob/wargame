-- Closes what the penetration test of 2026-10-10 found (issue #12):
--
-- * claim_load took the budget from the caller (up to 10000) and let
--   p_force skip it, so one guest could claim 2500 for a made up room and
--   2500 for a made up pad and lock everybody else out of multiplayer. The
--   budget now has a ceiling kept in the database, loads are capped at what
--   a real room or phone costs, and p_force is ignored (no game sends it).
-- * record_round counted any account as a beaten opponent, so a farmer
--   could name the best pilots every round. Only pilots whose game sent a
--   heartbeat in the last five minutes count now. Kills and damage are
--   also capped by the time since the pilot's last round, and a pilot
--   records at most 300 rounds a day.
-- * Badges took the unlock time from the client ('2001-01-01' went in).
-- * Call signs could carry control and invisible characters (right to left
--   override, zero width space) and surrounding blanks.

-- The project's Realtime budget, messages a second, as the plan allows.
-- Builds pass their own REALTIME_BUDGET; the smaller of the two counts.
create table if not exists private.settings (
  key text primary key,
  value integer not null
);
revoke all on private.settings from public, anon, authenticated;
insert into private.settings (key, value) values ('realtime_budget', 400)
on conflict (key) do nothing;

create or replace function public.claim_load(
  p_room text,
  p_load integer,
  p_budget integer,
  p_force boolean default false
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  v_pad boolean := left(p_room, 4) = 'pad-';
  -- A full room of four with CPU tanks in capture the flag costs 252, a
  -- room of five 370; four phones on one screen 128.
  v_load integer := least(
    greatest(coalesce(p_load, 0), 0),
    case when left(p_room, 4) = 'pad-' then 160 else 400 end
  );
  v_budget integer := least(
    greatest(coalesce(p_budget, 80), 1),
    coalesce(
      (select s.value from private.settings s where s.key = 'realtime_budget'),
      400
    )
  );
  v_other integer;
  v_held integer;
begin
  if me is null then
    raise exception 'not signed in';
  end if;
  if p_room is null or char_length(p_room) not between 1 and 16 then
    raise exception 'not a room';
  end if;
  -- One claim at a time, so two cannot both take the last room.
  perform pg_advisory_xact_lock(hashtextextended('live_rooms', 15));
  delete from public.live_rooms r where r.seen_at < now() - interval '150 seconds';

  select r.load into v_held from public.live_rooms r where r.room = p_room;
  select coalesce(sum(r.load), 0) into v_other
  from public.live_rooms r where r.room <> p_room;

  if v_held is not null then
    if v_load <= v_held or v_other + v_load <= v_budget then
      update public.live_rooms r set load = v_load, seen_at = now()
      where r.room = p_room;
      return true;
    end if;
    update public.live_rooms r set seen_at = now() where r.room = p_room;
    return false;
  end if;

  -- A pilot is in one room and has one pairing at a time: an older claim
  -- of the same kind goes, so nobody holds the budget with made up rooms.
  delete from public.live_rooms r
  where r.claimed_by = me and (left(r.room, 4) = 'pad-') = v_pad;
  select coalesce(sum(r.load), 0) into v_other from public.live_rooms r;
  if v_other + v_load > v_budget then
    return false;
  end if;
  insert into public.live_rooms (room, claimed_by, load)
  values (p_room, me, v_load);
  return true;
end;
$$;

revoke execute on function public.claim_load from public, anon;
grant execute on function public.claim_load to authenticated;

-- Call signs: no control or invisible characters, no blanks around them.
create or replace function private.clean_name(p_name text)
returns text
language sql
immutable
set search_path = ''
as $$
  select coalesce(
    nullif(
      btrim(
        regexp_replace(
          coalesce(p_name, ''),
          '[[:cntrl:]­​-‏‪-‮⁠-⁩﻿]',
          '',
          'g'
        )
      ),
      ''
    ),
    'Panzer'
  );
$$;

create or replace function private.clean_name_trigger()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.name := left(private.clean_name(new.name), 16);
  return new;
end;
$$;

drop trigger if exists players_clean_name on public.players;
create trigger players_clean_name
  before insert or update of name on public.players
  for each row execute function private.clean_name_trigger();

drop trigger if exists scores_clean_name on public.scores;
create trigger scores_clean_name
  before insert or update of name on public.scores
  for each row execute function private.clean_name_trigger();

-- Names already written go through the same cleaning.
update public.players set name = name
where name is distinct from left(private.clean_name(name), 16);
update public.scores set name = name
where name is distinct from left(private.clean_name(name), 16);

-- Badges: unlocked when they are written, whatever the client says.
create or replace function private.achievement_now()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.unlocked_at := now();
  return new;
end;
$$;

drop trigger if exists achievements_now on public.achievements;
create trigger achievements_now
  before insert or update on public.achievements
  for each row execute function private.achievement_now();

-- record_round: same parameters and result as in 0017.
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
  v_name text := left(private.clean_name(p_name), 16);
  v_kills integer := least(greatest(coalesce(p_kills, 0), 0), 15);
  v_damage integer := least(greatest(coalesce(p_damage, 0), 0), 5000);
  v_shots integer := least(greatest(coalesce(p_shots, 0), 0), 3000);
  v_hits integer;
  v_survival integer := least(greatest(coalesce(p_survival, 0), 0), 1800);
  v_last timestamptz;
  v_since integer;
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
  if (
    select count(*) from public.round_results r
    where r.player_id = me and r.created_at > now() - interval '1 day'
  ) >= 300 then
    raise exception 'too many rounds today';
  end if;
  -- Nobody survives longer than the time since the last recorded round,
  -- and nobody scores faster than a kill every four seconds and 150
  -- damage a second of it (a fast round has a few kills in 10 s).
  if v_last is not null then
    v_since := ceil(extract(epoch from now() - v_last))::integer;
    v_survival := least(v_survival, v_since);
    v_kills := least(v_kills, 1 + v_since / 4);
    v_damage := least(v_damage, 200 + v_since * 150);
  end if;
  v_hits := least(greatest(coalesce(p_hits, 0), 0), v_shots);

  insert into public.scores as s (id, name)
  values (me, v_name)
  on conflict (id) do nothing;
  select s.rating into v_rating from public.scores s where s.id = me for update;

  -- Only accounts that are playing right now count as opponents (their
  -- game sends a heartbeat every minute), at most eight each way, as many
  -- as a full room holds.
  with beaten as (
    select distinct b as id from unnest(coalesce(p_beaten, '{}')) b
    where b <> me
      and exists (select 1 from auth.users u where u.id = b)
      and exists (
        select 1 from public.online_pilots o
        where o.id = b and o.seen_at > now() - interval '5 minutes'
      )
    limit 8
  ), beaten_by as (
    select distinct b as id from unnest(coalesce(p_beaten_by, '{}')) b
    where b <> me
      and exists (select 1 from auth.users u where u.id = b)
      and exists (
        select 1 from public.online_pilots o
        where o.id = b and o.seen_at > now() - interval '5 minutes'
      )
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
