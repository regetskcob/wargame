-- Realtime counts every message once sent and once for every receiver, for
-- the whole project at once (README, "Realtime limits"). The free plan
-- carries one small room at a time: two rooms playing together would throw
-- both out. So rooms take one of a few slots here as soon as a second pilot
-- is in them, since only then do messages flow. Everybody in the room
-- refreshes the slot once a minute; a room that falls silent gives it back
-- after two and a half minutes. A pilot alone, solo rounds included, needs
-- no slot.

create table public.live_rooms (
  room text primary key check (char_length(room) between 1 and 16),
  claimed_by uuid not null references auth.users (id) on delete cascade,
  seen_at timestamptz not null default now()
);

comment on table public.live_rooms is 'Rooms with more than one pilot, for the Realtime budget';

-- No policies: written through claim_room and only counted through
-- live_room_count, so nobody learns which rooms are playing.
alter table public.live_rooms enable row level security;

-- Takes or refreshes the slot of p_room. False when every one of the
-- p_max slots belongs to another room. p_max comes from the build, as the
-- plan the project is on decides it.
create function public.claim_room(p_room text, p_max integer default 1)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  v_max integer := least(greatest(coalesce(p_max, 1), 1), 50);
begin
  if me is null then
    raise exception 'not signed in';
  end if;
  if p_room is null or char_length(p_room) not between 1 and 16 then
    raise exception 'not a room';
  end if;
  -- One claim at a time, so two rooms cannot both take the last slot.
  perform pg_advisory_xact_lock(hashtextextended('live_rooms', 15));
  delete from public.live_rooms r where r.seen_at < now() - interval '150 seconds';

  update public.live_rooms r set seen_at = now() where r.room = p_room;
  if found then
    return true;
  end if;
  -- A pilot is in one room at a time: an older claim of theirs goes, so
  -- nobody holds every slot with made up rooms.
  delete from public.live_rooms r where r.claimed_by = me;
  if (select count(*) from public.live_rooms) >= v_max then
    return false;
  end if;
  insert into public.live_rooms (room, claimed_by) values (p_room, me);
  return true;
end;
$$;

revoke execute on function public.claim_room from public, anon;
grant execute on function public.claim_room to authenticated;

-- How many rooms hold a slot right now, for the start page.
create function public.live_room_count()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer from public.live_rooms r
  where r.seen_at > now() - interval '150 seconds';
$$;

revoke execute on function public.live_room_count from public;
grant execute on function public.live_room_count to anon, authenticated;
