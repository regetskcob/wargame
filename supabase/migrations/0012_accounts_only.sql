-- Only pilots with an account are ranked. Guests play on, but their rounds
-- earn no experience, rating or badges, and they do not show up in the
-- leaderboards. Rows guests left so far stay: once a guest creates an
-- account, the id stays the same and the old progress shows again.

create function public.is_account(p_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from auth.users u where u.id = p_id and not u.is_anonymous
  );
$$;

revoke execute on function public.is_account from public;
grant execute on function public.is_account to anon, authenticated;

-- record_round writes every round to round_results, so refusing guests here
-- refuses the whole call, totals included.
create function public.refuse_guest_rounds()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_account(new.player_id) then
    raise exception 'guests are not ranked';
  end if;
  return new;
end;
$$;

revoke execute on function public.refuse_guest_rounds from public, anon, authenticated;

create trigger round_results_accounts_only
  before insert on public.round_results
  for each row
  execute function public.refuse_guest_rounds();

-- The all time leaderboard: accounts only, and the own row.
drop policy "Scores are readable by everyone" on public.scores;
create policy "Scores of accounts are readable by everyone"
  on public.scores for select
  using (auth.uid() = id or public.is_account(id));

-- The weekly leaderboard: accounts only.
create or replace view public.weekly_scores
  with (security_invoker = false)
as
select
  r.player_id as id,
  (array_agg(r.name order by r.created_at desc))[1] as name,
  count(*)::integer as rounds,
  (count(*) filter (where r.won))::integer as wins,
  sum(r.kills)::integer as kills,
  sum(r.damage)::integer as damage,
  sum(r.xp)::integer as xp,
  sum(r.rating_change)::integer as rating_change
from public.round_results r
where r.created_at >= date_trunc('week', now())
  and public.is_account(r.player_id)
group by r.player_id;
