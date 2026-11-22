-- The weekly leaderboard gave way to the single leaderboard sorted by
-- points; no client reads weekly_scores any more. Dropping the view and its
-- security definer function removes one more way to read other pilots'
-- round totals.

drop view if exists public.weekly_scores;
drop function if exists private.weekly_scores();
