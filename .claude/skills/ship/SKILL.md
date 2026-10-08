---
name: ship
description: Bring the current branch onto main and push it - merge origin/main, run format, analyze, tests and the web, iOS and Android builds, then push and watch CI. Use when the user says "auf main", "pushen", "mergen", "ausliefern", "ship it" or a feature is done.
---

# Ship to main

The user merges straight into `main`, without pull requests. A push to `main`
deploys the web game at once (GitHub Pages), so nothing goes up red.

1. `git fetch origin` and look at `git status`. Commit open work first, in
   English, one imperative sentence per commit, no prefix, ending with the
   attribution lines from the system reminder.
2. Merge `origin/main` into the branch (in an app-made worktree use the
   `sync_with_base_branch` tool). Resolve conflicts; the files under `lib/src/game/tank_game/`,
   `l10n.dart` and `README.md` are the usual hot spots, keep both sides.
3. Run `tool/verify.sh` (format, analyze, tests, web, iOS, Android). It takes
   a few minutes; run it in the background and wait for it. Fix and rerun
   until it ends with "All green".
4. If a migration is part of the change, push it to the hosted project
   before the game (see `/db-migration`), because the client must never call
   functions the database lacks.
5. `git push origin HEAD:main`. If main moved meanwhile, merge again and
   repeat from 3.
6. `gh run list --branch main --limit 3` and `gh run watch <id>` for `ci` and
   `pages` once, without polling loops.
7. Report: commit hash on main, which builds ran, CI result, and anything
   the user still has to do by hand (dashboard settings, store uploads).
   Update the matching memory entry if a roadmap item moved.
