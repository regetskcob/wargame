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
- The iOS build embeds the watch app; the watch must be signed with the same
  team.
- Run `/ship` first, so main is green and holds the version bump.
- Afterwards: `gh run watch` once, report the build number, and update the
  store memory entries with what is still open in the store consoles.
