-- Who is playing right now, for the home screen widget. Realtime Presence
-- already knows this, but a widget cannot hold a channel open, it only gets
-- a short HTTP request every few minutes. So every running game sends a
-- heartbeat once a minute, and anybody can ask how many were seen lately.

create table public.online_pilots (
  id uuid primary key references auth.users (id) on delete cascade,
  in_match boolean not null default false,
  seen_at timestamptz not null default now()
);

comment on table public.online_pilots is 'Last heartbeat of every running game';

create index online_pilots_seen_at on public.online_pilots (seen_at);

-- No policies: rows are written through ping_online and read only as counts
-- through online_status, so nobody learns who is online.
alter table public.online_pilots enable row level security;

create function public.ping_online(p_in_match boolean default false)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not signed in';
  end if;
  insert into public.online_pilots as o (id, in_match, seen_at)
  values (me, coalesce(p_in_match, false), now())
  on conflict (id) do update
    set in_match = excluded.in_match, seen_at = excluded.seen_at;
  -- Keep the table small: drop games that went quiet a day ago.
  delete from public.online_pilots o where o.seen_at < now() - interval '1 day';
end;
$$;

revoke execute on function public.ping_online from public, anon;
grant execute on function public.ping_online to authenticated;

-- A game counts as online for two missed heartbeats after its last one.
create function public.online_status()
returns table (online integer, in_match integer, rounds_today integer)
language sql
stable
security definer
set search_path = ''
as $$
  select
    (select count(*)::integer from public.online_pilots o
      where o.seen_at > now() - interval '150 seconds'),
    (select count(*)::integer from public.online_pilots o
      where o.seen_at > now() - interval '150 seconds' and o.in_match),
    (select count(*)::integer from public.round_results r
      where r.created_at >= date_trunc('day', now()));
$$;

revoke execute on function public.online_status from public;
grant execute on function public.online_status to anon, authenticated;
