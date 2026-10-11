---
name: release-test
description: Run the release test plan of Panzergefecht (docs/release-test-plan.md) before a TestFlight, App Store or Google Play upload - build identity, the automated gate, function on every platform, load and reliability - and end with a GO / NO GO issue. Use when the user says "Release-Test", "vor dem Release testen", "Testplan", "QA vor dem Store", or when /release is about to upload.
---

# Release test

The plan is `docs/release-test-plan.md`; read it first, every time. It lists
each case with an id, where it comes from (#12, #21, #23), how it is checked
(auto / sim / owner) and its severity. This skill only says how to run it.

1. **Scope.** Read the version in `pubspec.yaml` and find the last
   "Raise the version" commit before it. Minor or major: everything. Patch:
   sections 1, 2, 5 and the smoke path, plus the cases of section 3 and 4
   whose area the diff touches (map files to areas with the table in
   `CLAUDE.md`). Say the scope and why in one line before starting.
2. **Build identity (section 1)** and the **automated gate (section 2)**:
   run them yourself, in this order, and stop at the first blocker:
   `tool/verify.sh` (full), the three-run flake check, the balance and
   trench simulations with the bands of the plan, the long defense
   benchmark (L3, tag `benchmark`), `--tags supabase` when Docker is there.
   L4 runs `integration_test/frame_timing_test.dart` through
   `flutter drive --profile` on the BoPad once the owner has it unlocked;
   on the Mac (`-d macos`) it only proves the scenes still run. Long runs
   go to the background; do the sim cases meanwhile.
3. **Function, load, reliability (sections 3–5), the sim rows.** Use
   `/play-local`: the web build in the built-in browser or headless Chrome
   (two browser profiles for two players), the iPhone 18 Pro, iPad Pro 13",
   Apple TV and watch simulators (reuse existing ones). Few screenshots,
   check by `read_page` and logs. Collect every unhandled error from all
   logs for R9. Never flood the hosted Realtime (L8), database attacks only
   in PGlite.
   For 3.13 build the last release from a worktree
   (`git worktree add ../wargame-prev <last "Raise the version" commit>`)
   and play it against the new build in both roles (old host, new guest
   and the other way round); remove the worktree afterwards.
4. **Fix or file.** A blocker or major found here is fixed in this session
   with a test (the usual `/ship` path, commit message as a sentence), then
   the affected cases run again. Minors go into the issue.
5. **Owner rows.** Do not wait for them. Bundle them at the end with exact
   steps (device, build, what to look at, what counts as pass).
6. **Report.** Open the issue "Release test x.y.z (build)" with
   `gh issue create`, in English, laid out as in section 7 of the plan:
   where it ran, one table per section, balance and load numbers next to
   the last release's, "Needs you", the verdict. Tell the user in German:
   the verdict as the first line, bold with ✅ / ⚠️ / ❌, then the issue link
   and what is left for them.
7. Keep the plan alive: a new finding that could come back becomes a row in
   `docs/release-test-plan.md` (id, source issue, how, severity), and a row
   that got a test changes from sim to auto. Commit that with the release.

`/release` uploads only after GO, or after "GO with owner rows" once the
owner did or waived those rows.
