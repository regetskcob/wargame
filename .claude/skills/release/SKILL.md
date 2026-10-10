---
name: release
description: Prepare a store release of Panzergefecht - version bump, TestFlight and Google Play uploads through the manual GitHub workflows, store texts and screenshots. Use when the user talks about TestFlight, App Store, Play Store, a new version or store assets.
---

# Store release

- **Version** in `pubspec.yaml` (`version: x.y.z+build`). The build number
  must rise for every upload to either store.
- **Store texts, icons, screenshots**: `store/ios` and `store/android`, each
  with a README of what goes where and which secrets the workflows need.
- **TestFlight**: workflow `testflight` (manual, `workflow_dispatch`, inputs
  `build`, `metadata`). Start with
  `gh workflow run testflight -f build=true -f metadata=false` only after the
  user says so; it uploads to App Store Connect.
- **Google Play**: workflow `play` (inputs `track`, `status`, `metadata`),
  e.g. `gh workflow run play -f track=internal -f status=draft`, again only
  on the user's word.
- **Archive for the Organizer** (manual upload, while the workflow lacks
  its secrets): from an up to date main checkout run `tool/archive_ios.sh`.
  It builds the watch app, then `flutter build ipa` (both with
  `--dart-define=ACCOUNTS=true`), checks watch app, versions, Supabase URL
  and signature, and copies the archive to the Organizer as
  `Panzergefecht <version> (<build>) <time>`. `tool/archive_ios.sh --upload`
  also sends it to App Store Connect (Apple account signed in to Xcode, one
  retry on a broken connection); pass it only on the user's word. Upload
  exactly that archive, never another one; build
  5 went out without a watch because a bare `Panzergefecht.xcarchive` made
  before the watch build sat next to the complete one. After processing,
  App Store Connect → TestFlight → build → "Apple Watch" must say yes.
  URL and key need no define, `Env` defaults to the live project.
  Never archive in Xcode on whatever `ios/Flutter/Generated.xcconfig` the
  last `flutter` command left behind: build 4 shipped with all defines
  glued into `SUPABASE_URL` and reached no server. Since then
  `tool/check_dart_defines.sh` stops such a build in Xcode, and the app
  logs `Server check failed: …` in the device log (`idevicesyslog -p
  Panzergefecht`) when it cannot reach Supabase.
- Before the upload, start the archived build once on a real device with a
  stored session gone (delete the app) and check the leaderboard loads.
- The iOS build embeds the watch app; the watch must be signed with the same
  team.
- Run `/ship` first, so main is green and holds the version bump.
- Afterwards: `gh run watch` once, report the build number, and update the
  store memory entries with what is still open in the store consoles.
