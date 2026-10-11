-- Who is who in a room (penetration test of issue #12, "room identity").
--
-- Anybody with the project's public key can broadcast into any room and
-- write any id into a message. Since this migration a game speaks with a
-- key of its own: its id is the start of the SHA-256 of its public key, a
-- presence carries the key, and every message carries a tag per receiver
-- that only the sender can make (lib/src/net/room_key.dart). Nobody can
-- speak for somebody else any more.
--
-- What tags cannot settle is who may lead the room: the presence says who
-- opened it and when everybody came, and both are whatever the client
-- writes. A player posing as the owner, or as the first to come, took the
-- host role and could end a defense or flag round for everybody. So every
-- game enters its key here when it joins a room, and the database keeps
-- who owns the room (the account that entered it first as its owner) and
-- when each key came, by the server's clock. Every client ranks the
-- pilots of the room by this list the same way: the owner, then whoever
-- came first.

create table public.room_pilots (
  room text not null check (char_length(room) between 1 and 16),
  -- The id the key speaks as, 16 hex digits.
  id text not null check (id ~ '^[0-9a-f]{16}$'),
  player_id uuid not null references auth.users (id) on delete cascade,
  owner boolean not null default false,
  joined_at timestamptz not null default now(),
  primary key (room, id)
);

create index room_pilots_player on public.room_pilots (player_id, joined_at);

comment on table public.room_pilots is 'Keys that entered a room, for the host ranking';

-- No policies: written through enter_room, read through room_order.
alter table public.room_pilots enable row level security;
revoke all on public.room_pilots from public, anon, authenticated;

-- Enters the key p_key (an X25519 public key, base64url without padding)
-- into p_room. With p_owner the pilot claims to have opened the room: the
-- room then belongs to their account, unless another account owns it
-- already. Returns whether the key counts as the owner's.
create function public.enter_room(p_room text, p_key text, p_owner boolean)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  v_key bytea;
  v_id text;
  v_owner boolean;
begin
  if me is null then
    raise exception 'not signed in';
  end if;
  if p_room is null or p_room !~ '^[A-Za-z0-9-]{1,16}$' then
    raise exception 'not a room';
  end if;
  if p_key is null or p_key !~ '^[A-Za-z0-9_-]{43}$' then
    raise exception 'not a key';
  end if;
  v_key := decode(translate(p_key, '-_', '+/') || '=', 'base64');
  v_id := left(encode(sha256(v_key), 'hex'), 16);

  -- One entry at a time per room, so two cannot both become its owner.
  perform pg_advisory_xact_lock(hashtextextended('room_pilots:' || p_room, 20));
  -- A room lives as long as somebody plays in it; keys of a day ago are
  -- of games long closed.
  delete from public.room_pilots r where r.joined_at < now() - interval '1 day';

  -- A game enters every room it joins once and makes a new key for the
  -- next one; a few hundred a day are more than anybody plays.
  if (
    select count(*) from public.room_pilots r
    where r.player_id = me and r.joined_at > now() - interval '1 hour'
  ) >= 120 then
    raise exception 'too many rooms in the last hour';
  end if;

  v_owner := coalesce(p_owner, false) and not exists (
    select 1 from public.room_pilots r
    where r.room = p_room and r.owner and r.player_id <> me
  );

  insert into public.room_pilots as r (room, id, player_id, owner)
  values (p_room, v_id, me, v_owner)
  on conflict (room, id) do update
    -- The same key again (a channel that came back): its time stays.
    set owner = r.owner or excluded.owner
    where r.player_id = me;

  return exists (
    select 1 from public.room_pilots r
    where r.room = p_room and r.id = v_id and r.player_id = me and r.owner
  );
end;
$$;

revoke execute on function public.enter_room from public, anon;
grant execute on function public.enter_room to authenticated;

-- The keys of p_room in the order the clients rank them, with whether
-- the room has an owner at all (rooms opened by builds before this
-- migration have none). Ids and times say nothing about the accounts
-- behind them. A second player on a screen speaks without an account, so
-- anon may read as well.
create function public.room_order(p_room text)
returns table (id text, owner boolean, joined_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id, r.owner, r.joined_at
  from public.room_pilots r
  where r.room = p_room and r.joined_at > now() - interval '1 day'
  order by r.owner desc, r.joined_at, r.id
  limit 200;
$$;

revoke execute on function public.room_order from public;
grant execute on function public.room_order to anon, authenticated;
