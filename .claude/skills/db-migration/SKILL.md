---
name: db-migration
description: Add or change a Supabase migration for Panzergefecht (tables, RLS policies, the record_round RPC, leaderboards), check it locally without Docker, regenerate the typed models and push it to the hosted project. Use for any change under supabase/ or lib/src/db/.
---

# Database migration

Hosted project: `wowtrfleffnfaiadhujj`. Migrations are numbered
`supabase/migrations/NNNN_snake_name.sql`; take the next free number (the
session hook prints the newest one). Never edit a migration that is live,
add a new one.

1. **Write** the SQL. Keep the hardening from 0011/0012 intact: scores only
   change through `record_round` (security definer, clamped numbers, rate
   limit), guests (anonymous users) get no rating, policies only expose the
   caller's own rows where that applies. New functions: `set search_path`,
   revoke from `public`/`anon` unless guests need them.
2. **Check without Docker** in the scratchpad: PGlite from npm, a small stub
   for the `auth` schema (`auth.uid()`, `auth.jwt()`, `auth.users`), then run
   all migrations in order and a few calls as different users. If Docker is
   running, `supabase start` + `supabase db reset` is the full check.
3. **Types**: update `supabase/schema.json` to match, then
   `dart run supabase_typegen --output lib/src/db/supabase_schema.g.dart --import package:supabase_flutter/supabase_flutter.dart < supabase/schema.json`.
   Put the default fallbacks for later-added columns back (README, section
   "Regenerating the typed database models").
4. **Client**: the game must keep working against a database without the
   migration (old deploys, local stacks). Catch the missing function or
   column and degrade.
5. **Push** without asking (the user has given a standing go-ahead), as
   soon as step 2 passed and before the client code reaches main. Say in
   the report that it went live. From a worktree first copy the link state:
   `cp -R /Users/regetskcob/wargame/supabase/.temp supabase/.temp`, then
   `supabase db push`. Confirm with `supabase migration list`.
6. Record the new live migration in memory and, if behaviour changed, in the
   README.

The Supabase MCP server (`.mcp.json`) can list tables, run read-only SQL and
show logs once it is authorised (`/mcp`); prefer it for inspecting the live
database over ad-hoc REST calls.
