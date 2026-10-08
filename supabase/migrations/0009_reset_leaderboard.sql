-- Fresh start after the big gameplay changes: clears every finished round,
-- every pilot's totals, rating and experience, and every badge. Accounts and
-- profiles stay.

truncate table public.round_results, public.scores, public.achievements
  restart identity;
