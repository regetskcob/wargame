-- Badges a pilot has earned, one row each. The game decides when a badge is
-- earned and writes it once.
create table public.achievements (
  player_id uuid not null references auth.users (id) on delete cascade,
  code text not null check (char_length(code) <= 32),
  unlocked_at timestamptz not null default now(),
  primary key (player_id, code)
);

comment on table public.achievements is 'Badges earned per pilot';

alter table public.achievements enable row level security;

create policy "Achievements are readable by everyone"
  on public.achievements for select
  using (true);

create policy "Players can add their own achievements"
  on public.achievements for insert
  with check (auth.uid() = player_id);
