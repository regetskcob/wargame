-- Counts the rounds that moved a pilot's rating, that is the rounds with at
-- least one rated opponent. Until a pilot has one, the rating is still the
-- starting value and the leaderboard shows a dash instead of 1000.

alter table public.scores
  add column rated_rounds integer not null default 0;

comment on column public.scores.rated_rounds is
  'Rounds with at least one rated opponent';

update public.scores s
set rated_rounds = r.rated
from (
  select player_id, count(*)::integer as rated
  from public.round_results
  where opponents > 0
  group by player_id
) r
where r.player_id = s.id;

create function public.count_rated_round()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.scores s
  set rated_rounds = s.rated_rounds + 1
  where s.id = new.player_id;
  return new;
end;
$$;

revoke execute on function public.count_rated_round from public, anon, authenticated;

create trigger round_results_rated
  after insert on public.round_results
  for each row
  when (new.opponents > 0)
  execute function public.count_rated_round();
