-- Slots by load instead of by number (README, "Rooms and room sizes").
-- Rooms and phone controllers cost Realtime very different amounts: a
-- room of two about 44 messages a second, with CPU tanks 70, a paired
-- phone 32, a full room of four with CPU tanks 227. Every slot now carries
-- the load its holder announces, and a new one is let in while the loads
-- of all slots together stay within the budget the build passes in.
--
-- Rooms are keyed by their code, phone controllers by `pad-` and their
-- pairing code. A pilot holds at most one of each.

alter table public.live_rooms
  add column load integer not null default 70
  check (load between 0 and 2500);

comment on column public.live_rooms.load is 'Realtime messages a second the holder announced';

-- Takes or refreshes the slot of p_room with p_load. False when the other
-- slots leave no room for it within p_budget; a slot already held then
-- keeps its old load. Lowering a load always works. p_force takes the slot
-- regardless, for a phone that joins a room which drops its CPU tanks for
-- it and so makes room for itself.
create function public.claim_load(
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
  v_load integer := least(greatest(coalesce(p_load, 0), 0), 2500);
  v_budget integer := least(greatest(coalesce(p_budget, 80), 1), 10000);
  v_pad boolean := left(p_room, 4) = 'pad-';
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
    if p_force or v_load <= v_held or v_other + v_load <= v_budget then
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
  if not p_force and v_other + v_load > v_budget then
    return false;
  end if;
  insert into public.live_rooms (room, claimed_by, load)
  values (p_room, me, v_load);
  return true;
end;
$$;

revoke execute on function public.claim_load from public, anon;
grant execute on function public.claim_load to authenticated;

-- The loads of all slots together, for the start page.
create function public.live_load()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(r.load), 0)::integer from public.live_rooms r
  where r.seen_at > now() - interval '150 seconds';
$$;

revoke execute on function public.live_load from public;
grant execute on function public.live_load to anon, authenticated;

-- Games from before this migration still call claim_room: they count as
-- a room of two with CPU tanks within the free plan's budget.
create or replace function public.claim_room(p_room text, p_max integer default 1)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select public.claim_load(p_room, 70, 80);
$$;
