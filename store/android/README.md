# Google Play

**Maintainer document.** Everything the Play Console needs for
Panzergefecht on phones, tablets, Wear OS watches and Android TV: texts,
pictures, the answers to Google's questionnaires and the release steps.
The folders follow the layout of `fastlane supply`: `tool/release.sh
android` uploads bundle, texts and pictures from the Mac (see
[Deployment](#deployment)). Every file can just as well be pasted into the
Play Console by hand (Store presence > Main store listing).

**In a fork**, replace what belongs to the maintainer's account: the
application id `de.regetskcob.wargame` (`applicationId` and `namespace` in
`android/app/build.gradle.kts`, the Kotlin package under
`android/app/src/main/kotlin/`, `android/fastlane/Appfile`), your own upload
key in `android/key.properties`, your own Play service account, and the
names and texts under `metadata/`. The application id can never change
after the first upload. More in [forking.md](../../docs/forking.md).

## Contents

- [Files](#files)
- [Build and signing](#build-and-signing)
- [Deployment](#deployment)
- [Wear OS](#wear-os)
- [Answers in the Play Console](#answers-in-the-play-console)
- [Open before publishing](#open-before-publishing)

## Files

| Field in the Play Console | File |
| --- | --- |
| App name (max. 30) | `metadata/<lang>/title.txt` |
| Short description (max. 80) | `metadata/<lang>/short_description.txt` |
| Full description (max. 4000) | `metadata/<lang>/full_description.txt` |
| Release notes (max. 500) | `metadata/<lang>/changelogs/default.txt`, for one version `<versionCode>.txt` |
| App icon 512 × 512 | `metadata/<lang>/images/icon.png` |
| Feature graphic 1024 × 500 | `metadata/<lang>/images/featureGraphic.png` |
| Phone screenshots (1080 × 1920) | `metadata/<lang>/images/phoneScreenshots/*.png` |
| 7" tablet screenshots (1920 × 1200) | `metadata/<lang>/images/sevenInchScreenshots/*.png` |
| 10" tablet screenshots (2560 × 1600) | `metadata/<lang>/images/tenInchScreenshots/*.png` |
| Wear OS screenshots (square, at least 384 × 384) | `metadata/<lang>/images/wearScreenshots/*.png` |
| Android TV screenshots (1920 × 1080, no captions) | `metadata/<lang>/images/tvScreenshots/*.png` |
| Android TV banner (1280 × 720) | `metadata/<lang>/images/tvBanner.png` |

`<lang>` is `de-DE` or `en-US`. Play allows no side more than twice as long
as the other, so the 6.9" pictures from the App Store do not fit.
`tool/store/compose.py` builds both sets and the feature graphic from the
same raw pictures as the App Store (see
[`store/ios/README.md`](../ios/README.md)), and
`tool/store/horizont_icons.py` copies the launcher icons (classic, and
adaptive with a monochrome layer) and the Play icon from the design system
Horizont:

```sh
pip3 install --user pillow
tool/release.sh graphics <raw dir>
python3 tool/store/horizont_icons.py ../horizont
```

The phone and tablet screenshots show the iOS raw pictures without the
status bar; the game draws the same picture on Android. The TV pictures
come from a running Android TV emulator (profile `tv_1080p`):
`tool/release.sh shots <raw dir> atv`, then `tool/release.sh graphics <raw
dir>`.

## Build and signing

Application id `de.regetskcob.wargame` as on iOS, name Panzergefecht.

1. Create the upload key once and fill in `android/key.properties` after
   `android/key.properties.example` (git ignores both the file and the
   key).
2. Build with `flutter build appbundle --release
   --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...`; the
   result is `build/app/outputs/bundle/release/app-release.aab`.
   `tool/release.sh android` does this for you (see
   [Deployment](#deployment)).
3. Keep **Play App Signing** on in the Play Console: Google holds the app
   signing key, the maintainer only the upload key.
4. The versionCode must rise with every upload. It is the build number
   after the `+` in `version:` in `pubspec.yaml`; the part before it is the
   versionName.

Without `key.properties` Gradle signs with the debug key. A manual run of
the `ci` workflow builds that way, but Play does not accept such a bundle.

## Deployment

Builds are made and uploaded locally only, never in CI (see
[CI minutes](../../docs/development.md#ci-minutes)). `tool/release.sh
android` builds the signed bundle with `--dart-define=ACCOUNTS=true` (the
Supabase URL and key are the defaults in `Env`), checks the signature and
the Supabase URL, keeps a copy in `build/release/` and, with `--upload`,
sends it through `fastlane supply` from `android/fastlane`:

```sh
tool/release.sh android phone                          # build and check only
tool/release.sh android phone --upload internal        # draft in internal testing
tool/release.sh android phone --upload internal --metadata --completed
tool/release.sh android wear --upload internal         # Wear OS, its own track
```

| Option | Meaning |
| --- | --- |
| `phone` / `wear` | phones and tablets, or Wear OS watches, see [Wear OS](#wear-os) |
| `--upload <track>` | `internal` (internal testing), `alpha` (closed), `beta` (open), `production` |
| `--completed` | release at once instead of as a draft; only once the store listing and questionnaires are complete |
| `--metadata` | upload texts, icon, feature graphic and screenshots too |

Before an upload, run the
[release test plan](../../docs/release-test-plan.md).

### One-time setup

1. **Create the app:** Play Console > Create app, name "Panzergefecht",
   language German, game, free.
2. **First upload by hand:** the API only works with an app that already
   has a bundle. Build locally with `key.properties` and upload
   `app-release.aab` under Test and release > Internal testing, confirming
   Play App Signing with the upload key.
3. **Service account:** in the Google Cloud Console (the Play Console's
   project) enable the *Google Play Android Developer API*, create a
   service account and a JSON key for it. In the Play Console under Users
   and permissions, invite the service account with "Release apps" and
   "Manage store presence" for Panzergefecht.
4. **Check:** put the JSON file at `android/play-service-account.json`
   (git ignores it; `PLAY_JSON_KEY` points elsewhere), then in `android/`:

   ```sh
   bundle install
   bundle exec fastlane validate
   ```

### Other lanes

`tool/release.sh android` builds and uploads bundles (above). The other
lanes run by hand in `android/`:

```sh
bundle exec fastlane metadata                        # texts and pictures only
bundle exec fastlane promote from:internal to:alpha
```

Without `--completed` a release lands as a draft and has to be released in
the Play Console. As long as the app has never been published, the API
only accepts drafts anyway.

## Wear OS

The same app with the same package name runs on Wear OS watches (Galaxy
Watch 4 and newer, Pixel Watch), see
[Wear OS](../../docs/platforms.md#wear-os). Play lists it as a form factor
of its own, with its own tracks (`wear:internal`, `wear:production`, …)
and its own bundle:

- `flutter build appbundle --release --android-project-arg=wear=true` adds
  the manifest from `android/wear/` (`android.hardware.type.watch`,
  standalone, vibration), sets minSdk 30 (Wear OS 3) and adds 100000 to the
  versionCode, so it never collides with the phone bundle.
- `tool/release.sh android wear --upload internal` uploads it; promote it
  in `android/` with `bundle exec fastlane promote form_factor:wear
  from:internal to:production`.

Once in the Play Console: Test and release > Settings > Form
factors > add Wear OS and accept the Wear OS guidelines. Only then do the
`wear:` tracks exist. Wear OS needs screenshots of its own (square, only
the app, without a frame or round mask), and the review looks at the app
on a watch.

### Wear OS screenshots

The pictures in `wearScreenshots/` (454 × 454, `wear-01-menu` to
`wear-04-defense`) come from the round emulator (device
`wearos_large_round`, system image `android-36;android-wear-signed`).
Launch arguments do not reach the preferences on Android, so scene and
language go into a debug build as defines, one build per picture:

```sh
flutter build apk --debug --android-project-arg=wear=true \
  --dart-define=SHOTS=true --dart-define=SHOT_SCENE=battle --dart-define=SHOT_LANG=de
adb install -r -d build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n de.regetskcob.wargame/.MainActivity
# wait about 25 s for the scene to settle; much longer, and the battle may be over
adb exec-out screencap -p > wear-03-battle.png
```

The scenes are the same as on the Apple Watch: `menu`, `lobby`, `battle`,
`defense`. `screencap` returns the whole square without a frame; the black
corners come from the app's own round layout, as on every round watch.

## Answers in the Play Console

**Data safety:** no sharing with third parties, no tracking, data
encrypted in transit (HTTPS to Supabase). Collected only for app
functionality and account management:

- Personal info → email address (optional, only who secures their account)
- Personal info → user IDs (the anonymous id of the guest account)
- App activity → other user-generated content (call sign, vehicle, scores)
- App activity → app interactions (statistics, rounds, rating)
- Device or other IDs (one id per installation) and App info and
  performance → diagnostics, both for analytics: Google's ML Kit behind
  the QR scanner (`mobile_scanner`) sends them to Google, not to third
  parties, see <https://developers.google.com/ml-kit/android-data-disclosure>

**Advertising ID:** no; the bundle has no `AD_ID` permission and no ad SDK.

**Content rating (IARC questionnaire):** category game. Cartoon violence
against vehicles and tiny soldiers seen from above; where a soldier is run
over, a small red stain stays and dries brown (`BloodSplat` in
`lib/src/game/components/soldier.dart`), so "blood: yes, minimal". Players
do not chat, but see call signs others chose in rooms and the leaderboard.
That should come out at USK 12 / PEGI 12.

**Target audience:** 13 and older, so the app does not fall under the
Families policy.

**App access:** every feature is available without credentials ("ALS GAST
SPIELEN", play as guest). Use the text from
`../ios/metadata/review_information/notes.txt` as the note.

**Ads:** no. **Category:** Games > Action, tags Strategy and Multiplayer.

**Camera:** the app asks for the camera only to read the QR code of a
waiting room. The picture stays on the device, so data safety lists
nothing for the picture itself, only ML Kit's diagnostics (above). The
camera is declared optional, so devices without one (televisions among
them) still see the app in the store.

**Privacy policy URL:** `https://panzergefecht.de/datenschutz/` (as in the
App Store).

**Account deletion (data safety):** in the app under account > "Konto
löschen" (delete account). As the web address for deletion requests
without the app, give the same privacy URL; it describes deletion by
e-mail.

## Open before publishing

Status of the maintainer's account; a fork goes through the same steps.

1. **Closed test:** new personal developer accounts need at least 12
   testers in a closed test (`alpha`) for 14 days before production. The
   testers join through a Google Group (see `[params.beta]` in
   `site/hugo.toml`); `metadata/<lang>/testflight.txt` in the iOS folder
   works as the testing note.
2. **The one-time setup above:** create the app, first upload by hand,
   service account.
3. **Wear OS:** add the form factor in the Play Console, upload the
   screenshots from `wearScreenshots/`, play the app once on a real watch.
