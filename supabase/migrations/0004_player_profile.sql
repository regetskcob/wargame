-- Name and look of a pilot, so they come back on the next visit.
alter table public.players
  add column style integer not null default 0,
  add column updated_at timestamptz not null default now();

comment on table public.players is 'Call sign and vehicle of every pilot';
comment on column public.players.style is
  'Vehicle and paint scheme in one number, as the game sends it';
