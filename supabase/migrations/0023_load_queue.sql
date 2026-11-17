-- A queue for the Realtime budget.
--
-- When every slot of the budget is taken (0015, 0016), a pilot who came
-- into a room used to be sent away to try again later, and whoever tried
-- again first got the next free slot. Now the pilot waits in load_queue:
-- queue_claim takes the slot for the room as soon as the pilot is first in
-- line and the load fits, and tells everybody else their place and a rough
-- wait. Waiting pilots ask every 10 seconds through the database, which
-- costs nothing of the Realtime budget; who stops asking for 45 seconds
-- leaves the line. claim_load refuses new rooms to everybody while somebody
-- who came earlier still waits, so older builds cannot jump the queue.

create table public.load_queue (
  user_id uuid primary key references auth.users (id) on delete cascade,
  joined_at timestamptz not null default now(),
  seen_at timestamptz not null default now()
);

comment on table public.load_queue is 'Pilots waiting for a slot of the Realtime budget';

-- No policies: only the functions below read and write it.
alter table public.load_queue enable row level security;

-- claim_load: as in 0022, with the queue check before a new claim.
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

  -- Who waits in the queue goes first: a new claim only passes when
  -- nobody who is still waiting joined it earlier (0023).
  if exists (
    select 1 from public.load_queue q
    where q.user_id <> me
      and q.seen_at > now() - interval '45 seconds'
      and q.joined_at < coalesce(
        (select m.joined_at from public.load_queue m where m.user_id = me),
        now()
      )
  ) then
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

-- Puts the caller in line (or keeps their place), and takes the slot for
-- p_room when they are first and it fits. The wait assumes a slot frees up
-- about every two minutes per playing room: a round lasts a few minutes,
-- and only a rough span is shown.
create function public.queue_claim(p_room text, p_load integer, p_budget integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  v_place integer;
  v_rooms integer;
begin
  if me is null then
    raise exception 'not signed in';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('live_rooms', 15));
  delete from public.load_queue q where q.seen_at < now() - interval '45 seconds';
  insert into public.load_queue (user_id) values (me)
  on conflict (user_id) do update set seen_at = now();

  if public.claim_load(p_room, p_load, p_budget) then
    delete from public.load_queue q where q.user_id = me;
    return jsonb_build_object('granted', true, 'place', 0, 'wait', 0);
  end if;

  select count(*)::integer + 1 into v_place from public.load_queue q
  where q.joined_at < (select m.joined_at from public.load_queue m where m.user_id = me);
  select count(*)::integer into v_rooms from public.live_rooms r
  where r.seen_at > now() - interval '150 seconds' and left(r.room, 4) <> 'pad-';
  return jsonb_build_object(
    'granted', false,
    'place', v_place,
    'wait', ceil(v_place::numeric / greatest(v_rooms, 1)) * 120
  );
end;
$$;
revoke execute on function public.queue_claim from public, anon;
grant execute on function public.queue_claim to authenticated;

-- Leaves the line, when the pilot gives up waiting.
create function public.queue_leave()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.load_queue q where q.user_id = auth.uid();
$$;
revoke execute on function public.queue_leave from public, anon;
grant execute on function public.queue_leave to authenticated;
