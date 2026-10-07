create table public.players (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now()
);

alter table public.players enable row level security;

create policy "Players are readable by everyone"
  on public.players for select
  using (true);

create policy "Players can insert their own row"
  on public.players for insert
  with check (auth.uid() = id);

create policy "Players can update their own row"
  on public.players for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "Players can delete their own row"
  on public.players for delete
  using (auth.uid() = id);
