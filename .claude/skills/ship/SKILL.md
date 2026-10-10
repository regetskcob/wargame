---
name: ship
description: Bring the current branch onto main and push it - merge origin/main, run format, analyze and tests (plus the web, iOS and Android builds when the change needs them), then push and watch CI. Use when the user says "auf main", "pushen", "mergen", "ausliefern", "ship it" or a feature is done.
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
3. Pick the check by the size of the change. Small changes to Dart code or
   docs only: `tool/verify.sh --quick` (format, analyze, tests); the `pages`
   workflow builds the web app anyway. The full `tool/verify.sh` (plus web,
   iOS, Android, several minutes) is for changes to `pubspec.*`, `ios/`,
   `android/`, `tvos/`, the watch app, assets, plugins or the version, for
   larger refactors and before store releases; run it in the background and
   wait for "All green". Fix and rerun until green. Judge it by its exit
   code or its last line; piped into `tail`, a failed run still looks
   successful to `&&`.
4. If a migration is part of the change, push it to the hosted project
   before the game, without asking (standing go-ahead; see
   `/db-migration`, it must have passed the PGlite check), because the
   client must never call functions the database lacks.
5. `git push origin HEAD:main`. If main moved meanwhile, merge again and
   repeat from 3.
6. `gh run list --branch main --limit 3` and `gh run watch <id>` for `ci` and
   `pages` once, without polling loops.
7. Report: commit hash on main, which builds ran, CI result, and anything
   the user still has to do by hand (dashboard settings, store uploads).
   The outcome is the first line of the reply, bold with a symbol, so it
   is not lost in the text: **✅ Auf main: `<hash>`, CI und Pages grün**,
   or **❌ …** with what failed.
   Update the matching memory entry if a roadmap item moved.
8. Free the disk. When the session's task is done with this ship (nothing
   left the user asked for here), run `tool/finish_worktree.sh` as the very
   last command, after the report is written. It removes this app-made
   worktree with its builds, its Xcode DerivedData and its merged branch,
   and refuses when anything is uncommitted or not on `origin/main`. Say
   in the report that the worktree is gone and the session can be
   archived; later work needs a new session. If the user still wants more
   in this session, skip it and run it after the last ship. Worktrees grew
   to 60 GB once because no session cleaned up after itself.
