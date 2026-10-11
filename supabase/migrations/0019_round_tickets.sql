-- Closes the two points the penetration test of 2026-10-10 left open
-- (issue #12):
--
-- * record_round trusted the client for rounds against CPU tanks: nothing
--   showed that a round had been played at all, so a script could send a
--   won round against four CPU tanks every eight seconds. A round now
--   starts with start_round, which hands out a ticket bound to the pilot
--   and the server's clock. record_round takes the ticket once and caps
--   the round by the time it really took (see "Rounds with a ticket").
-- * claim_load let anybody who knew a room code lower that room's load,
--   so rooms could over-commit the shared Realtime budget. Only the pilot
--   who claimed a slot may lower it now (see claim_load below).

-- Rounds with a ticket ------------------------------------------------------
--
-- A ticket is taken when the pilot's round starts (the countdown counts)
-- and names how many CPU tanks are in it. The round's time runs from the
-- ticket until it is recorded or until the pilot's next ticket, whichever
-- comes first: a new round only starts after the last one ended, so the
-- times of two rounds never overlap, and a pilot cannot earn more than the
-- time actually spent playing allows, however many tickets are taken.
-- That also lets the Apple Watch send rounds that waited for a fresh
-- phone token later (PendingRounds), nine seconds apart: each round keeps
-- its own time instead of the nine seconds since the round before.
--
-- Per second played a round yields at most what 0018 allowed for the time
-- since the last round, the rates a fast defense round with guns and mines
-- reaches: a kill every four seconds and 150 damage a second. CPU tanks
-- count up to the number the ticket names, at most four (a single player
-- round rolls one to four, a filled room or a capture the flag side never
-- faces more), and at most one every five seconds. A round under five
-- seconds earns the ten points for taking part and nothing else.
--
-- Tickets stay valid for a day, so a round the watch holds overnight still
-- counts; holding one longer earns nothing beyond what a single long round
-- does, since its time ends at the next ticket. A pilot holds at most
-- eight unused tickets, the oldest goes first.
--
-- Rounds without a ticket ---------------------------------------------------
--
-- Builds in the stores before this migration (and a watch round whose
-- start found no usable phone token) call record_round without a ticket,
-- as do callers with an unknown, foreign or expired one. Refusing them
-- would leave honest pilots of old builds without progress until they
-- update, so they still count, with clearly lower trust: CPU tanks count
-- for nothing (no rating, no experience for outlasting them), a win only
-- counts when a rated human opponent was outlasted, and kills and damage
-- are capped at a fifth of the ticket rates over the time since the last
-- round, at most ten minutes of it. A script sending a won round against
-- CPU tanks as often as allowed now earns about what honest play does.
-- A ticket that was already used is refused outright, so a round the
-- watch sent twice goes in once.

create table if not exists private.round_tickets (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references auth.users (id) on delete cascade,
  started_at timestamptz not null default now(),
  cpu smallint not null default 0 check (cpu between 0 and 4),
  used_at timestamptz
);
create index if not exists round_tickets_player
  on private.round_tickets (player_id, started_at);
-- Only start_round and record_round touch it.
alter table private.round_tickets enable row level security;
revoke all on private.round_tickets from public, anon, authenticated;

create or replace function public.start_round(p_cpu integer default 0)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  v_id uuid;
begin
  if me is null then
    raise exception 'not signed in';
  end if;
  if not public.is_account(me) then
    raise exception 'guests are not ranked';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(me::text, 11));
  delete from private.round_tickets t
  where t.player_id = me and t.started_at < now() - interval '1 day';
  delete from private.round_tickets t
  where t.id in (
    select t2.id from private.round_tickets t2
    where t2.player_id = me and t2.used_at is null
    order by t2.started_at desc
    offset 7
  );
  insert into private.round_tickets (player_id, cpu)
  values (me, least(greatest(coalesce(p_cpu, 0), 0), 4))
  returning id into v_id;
  return v_id;
end;
$$;

revoke execute on function public.start_round from public, anon;
grant execute on function public.start_round to authenticated;

-- record_round: the parameters of 0017 and the ticket. The old signature
-- goes, PostgREST finds this one for old builds too, as p_ticket has a
-- default.
drop function if exists public.record_round(
  text, smallint, boolean, integer, integer, integer, integer, integer,
  uuid[], uuid[], integer, integer, integer
);

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
  p_beaten_by uuid[] default '{}',
  p_cpu_beaten integer default 0,
  p_cpu_beaten_by integer default 0,
  p_cpu_rating integer default 1000,
  p_ticket uuid default null
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
  v_won boolean := coalesce(p_won, false);
  v_kills integer := least(greatest(coalesce(p_kills, 0), 0), 15);
  v_damage integer := least(greatest(coalesce(p_damage, 0), 0), 5000);
  v_shots integer := least(greatest(coalesce(p_shots, 0), 0), 3000);
  v_hits integer;
  v_survival integer := least(greatest(coalesce(p_survival, 0), 0), 1800);
  v_last timestamptz;
  v_since integer;
  v_start timestamptz;
  v_end timestamptz;
  v_used timestamptz;
  v_ticket_cpu integer;
  v_played integer;
  v_rating integer;
  v_opponents integer := 0;
  v_humans_beaten integer := 0;
  v_actual double precision := 0;
  v_expected double precision := 0;
  v_change integer := 0;
  v_gained integer;
  v_cpu_beaten integer := least(greatest(coalesce(p_cpu_beaten, 0), 0), 4);
  v_cpu_beaten_by integer := least(greatest(coalesce(p_cpu_beaten_by, 0), 0), 4);
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

  if p_ticket is not null then
    select t.started_at, t.used_at, t.cpu into v_start, v_used, v_ticket_cpu
    from private.round_tickets t
    where t.id = p_ticket and t.player_id = me
      and t.started_at > now() - interval '1 day'
    for update;
    if v_used is not null then
      raise exception 'round already recorded';
    end if;
  end if;

  if v_start is not null then
    update private.round_tickets t set used_at = now() where t.id = p_ticket;
    -- The round ended at the latest when the pilot's next one started.
    select least(now(), coalesce(min(t.started_at), now())) into v_end
    from private.round_tickets t
    where t.player_id = me and t.started_at > v_start;
    v_played := floor(extract(epoch from v_end - v_start))::integer;
    if v_played < 5 then
      v_kills := 0;
      v_damage := 0;
      v_won := false;
      v_cpu_beaten := 0;
      v_cpu_beaten_by := 0;
    end if;
    v_survival := least(v_survival, v_played);
    v_kills := least(v_kills, 1 + v_played / 4);
    v_damage := least(v_damage, 200 + v_played * 150);
    v_shots := least(v_shots, 10 + v_played * 6);
    v_cpu_beaten := least(v_cpu_beaten, v_ticket_cpu, v_played / 5);
    v_cpu_beaten_by := least(v_cpu_beaten_by, v_ticket_cpu - v_cpu_beaten);
  else
    -- Without a ticket: see "Rounds without a ticket" above.
    v_since := least(
      coalesce(ceil(extract(epoch from now() - v_last))::integer, 600),
      600
    );
    v_survival := least(v_survival, v_since);
    v_kills := least(v_kills, 1 + v_since / 20);
    v_damage := least(v_damage, 40 + v_since * 30);
    v_shots := least(v_shots, 10 + v_since * 6);
    v_cpu_beaten := 0;
    v_cpu_beaten_by := 0;
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
  v_humans_beaten := round(v_actual)::integer;

  if v_start is null and v_humans_beaten = 0 then
    v_won := false;
  end if;

  -- CPU tanks count as opponents with a fixed rating for their level.
  v_cpu_expected := 1.0 / (1 + power(10, (v_cpu_rating - v_rating) / 400.0));
  v_opponents := v_opponents + v_cpu_beaten + v_cpu_beaten_by;
  v_actual := v_actual + v_cpu_beaten;
  v_expected := v_expected + (v_cpu_beaten + v_cpu_beaten_by) * v_cpu_expected;

  if v_opponents > 0 then
    v_change := round(32.0 * (v_actual - v_expected) / v_opponents);
  end if;
  v_gained := 10 + 20 * v_kills + (case when v_won then 50 else 0 end)
    + least(v_damage, 2000) / 10
    -- Opponents outlasted: the rated ones and the CPU tanks.
    + 10 * round(v_actual)::integer;

  update public.scores s set
    name = v_name,
    wins = s.wins + (case when v_won then 1 else 0 end),
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
    me, v_name, greatest(0, least(p_tank, 50)), v_won, v_kills, v_damage,
    v_shots, v_hits, v_survival, v_opponents, v_change, v_gained
  );

  return query
    select s.rating, v_change, s.xp, v_gained
    from public.scores s where s.id = me;
end;
$$;

revoke execute on function public.record_round from public, anon;
grant execute on function public.record_round to authenticated;

-- claim_load ----------------------------------------------------------------
--
-- Everybody in a room refreshes its slot once a minute with the load the
-- room costs as they count it. Only the pilot who claimed the slot may
-- lower it now; the others refresh it and may raise it within the budget
-- (a pilot who just came in counts one more), but a lower load from them
-- only refreshes the slot. So a stranger who knows the room code can no
-- longer shrink a room's share and let rooms over-commit the budget.
--
-- When the claimer leaves, their client stops refreshing (or claims a slot
-- elsewhere, which drops this one as before). A slot whose claimer has not
-- refreshed for 150 seconds, the time a silent slot runs out, goes to the
-- next pilot who refreshes it: the stand-in host or any other pilot left
-- in the room takes it over and from then on may lower it. Until then the
-- room keeps the higher load it had, which only errs on the safe side.
-- Raising stays open to everybody, as before: a stranger could raise a
-- room's load within the budget, but the claimer lowers it again with the
-- next refresh.

alter table public.live_rooms
  add column if not exists claimer_seen_at timestamptz not null default now();

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
  v_claimer uuid;
  v_claimer_seen timestamptz;
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

  select r.load, r.claimed_by, r.claimer_seen_at
  into v_held, v_claimer, v_claimer_seen
  from public.live_rooms r where r.room = p_room;
  select coalesce(sum(r.load), 0) into v_other
  from public.live_rooms r where r.room <> p_room;

  if v_held is not null then
    -- The claimer is gone: whoever refreshes now holds the slot.
    if v_claimer <> me and v_claimer_seen < now() - interval '150 seconds' then
      update public.live_rooms r set claimed_by = me, claimer_seen_at = now()
      where r.room = p_room;
      v_claimer := me;
    elsif v_claimer = me then
      update public.live_rooms r set claimer_seen_at = now()
      where r.room = p_room;
    end if;
    if v_load = v_held
      or (v_load < v_held and v_claimer = me)
      or (v_load > v_held and v_other + v_load <= v_budget) then
      update public.live_rooms r set load = v_load, seen_at = now()
      where r.room = p_room;
      return true;
    end if;
    update public.live_rooms r set seen_at = now() where r.room = p_room;
    -- A lower load from somebody else is no refusal: the room fits.
    return v_load < v_held;
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
