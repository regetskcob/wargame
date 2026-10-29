---
name: release
description: Prepare a store release of Panzergefecht - version bump, local TestFlight and Google Play builds and uploads, store texts and screenshots. Use when the user talks about TestFlight, App Store, Play Store, a new version or store assets.
---

# Store release

- **Version** in `pubspec.yaml` (`version: x.y.z+build`). The build number
  must rise for every upload to either store.
- **Changelog**: add the version to `CHANGELOG.md` (newest first, in
  English, its 5 to 10 most important points as a list) and the same entry
  in German to `CHANGELOG.de.md`. Both files always carry the same versions,
  sections and points; every change to one goes into the other in the same
  commit.
- **Store texts, icons, screenshots**: `store/ios` and `store/android`, each
  with a README of what goes where and which keys the uploads need.
- **Builds only on this Mac, never in CI**: a macOS runner minute costs ten
  Linux minutes of the private repository's plan, so there are no release
  workflows (docs/development.md "CI minutes"). Every script below checks
  its result and uploads only with its flag; pass the flag only on the
  user's word.
- **Apple TV, Mac**: `tool/release.sh tvos|macos [--upload]`, same
  checks and Organizer copy as for iOS.
- **Google Play**: `tool/release.sh android phone|wear [--upload internal]
  [--metadata] [--completed]` builds with `android/key.properties`, refuses
  a debug-signed bundle or a glued Supabase URL, keeps a copy in
  `build/release/` and uploads through fastlane with
  `android/play-service-account.json`. The versionCode is the pubspec build
  number (plus 100000 for Wear OS).
- **App Store texts and screenshots**: `bundle exec fastlane ios metadata`
  in `ios/` with an App Store Connect API key in `ASC_KEY_ID`,
  `ASC_ISSUER_ID`, `ASC_KEY_PATH`.
- **iOS with the watch app**: from an up to date main checkout run
  `tool/release.sh ios`.
  It builds the watch app, then `flutter build ipa` (both with
  `--dart-define=ACCOUNTS=true`), checks watch app, versions, Supabase URL
  and signature, and copies the archive to the Organizer as
  `Panzergefecht <version> (<build>) <time>`. `tool/release.sh ios --upload`
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
- Then `/release-test` on that commit (plan in
  `docs/release-test-plan.md`). Upload only after its verdict is GO, or
  "GO with owner rows" once the owner did or waived those rows; never
  after NO GO.
- Afterwards: report the build number, and update the
  store memory entries with what is still open in the store consoles.
- Last, once the upload is through: `tool/finish_worktree.sh` fast-forwards
  the main checkout to `origin/main` and removes this
  session's worktree with its DerivedData and scratchpad, as at the end
  of `/ship`. The archive in the
  Organizer lives outside it and stays.
