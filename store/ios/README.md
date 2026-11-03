# App Store and TestFlight

**Maintainer document.** Everything App Store Connect needs for
Panzergefecht on iPhone, iPad, Apple Watch, Mac and Apple TV: texts,
pictures, the answers to Apple's questionnaires and the release steps. The
folders follow the layout of `fastlane deliver`, but every file can just as
well be pasted into App Store Connect by hand. The landing page reads its
texts and pictures from here too (see
[Landing page](../../docs/development.md#landing-page)).

**In a fork**, replace what belongs to the maintainer's account: the bundle
id `de.regetskcob.wargame` (Xcode projects, `ios/fastlane/Appfile`,
`tool/store_shots.sh`), the App Group `group.de.regetskcob.wargame`, the
team in `apple/Signing.xcconfig` (or your own, untracked
`apple/Signing.local.xcconfig`), the `applinks:` domains in
`ios/Runner/Runner.entitlements` and the app id in
[`apple-app-site-association`](apple-app-site-association), and the names,
URLs and texts under `metadata/`. More in
[forking.md](../../docs/forking.md).

## Contents

- [Files](#files)
- [Taking over the icon](#taking-over-the-icon)
- [Regenerating the screenshots](#regenerating-the-screenshots)
- [Answers in App Store Connect](#answers-in-app-store-connect)
- [TestFlight from the Mac](#testflight-from-the-mac)
- [Open before submission](#open-before-submission)
- [Universal Links](#universal-links)

## Files

| Field in App Store Connect | File |
| --- | --- |
| Name (max. 30) | `metadata/<lang>/name.txt` |
| Subtitle (max. 30) | `metadata/<lang>/subtitle.txt` |
| Promotional text (max. 170) | `metadata/<lang>/promotional_text.txt` |
| Description (max. 4000) | `metadata/<lang>/description.txt` |
| Keywords (max. 100) | `metadata/<lang>/keywords.txt` |
| What's new | `metadata/<lang>/release_notes.txt` |
| Support and marketing URL | `metadata/<lang>/support_url.txt`, `marketing_url.txt` |
| Privacy policy URL | `metadata/<lang>/privacy_url.txt` |
| Copyright, categories | `metadata/copyright.txt`, `metadata/primary_*.txt` |
| Notes for the review | `metadata/review_information/notes.txt` |
| Licence agreement (EULA), by hand and only instead of Apple's standard EULA | `license.txt` |
| TestFlight: description, what to test | `metadata/<lang>/testflight.txt` |
| App icon 1024 × 1024, no alpha | `icon/AppIcon-1024.png` |
| iPhone 6.9" (1320 × 2868) | `screenshots/<lang>/iphone-*.png` |
| iPhone 6.3" (1206 × 2622), the required "iPhone with Dynamic Island" slot | `screenshots/<lang>/iphone63-*.png` |
| iPad 13" (2752 × 2064) | `screenshots/<lang>/ipad-*.png` |
| Apple Watch Ultra 4 (422 × 514), upload by hand | `watch/<lang>/watch-*.png` |
| Mac (2880 × 1800), upload by hand | `mac/<lang>/mac-*.png` |
| Apple TV (3840 × 2160), upload by hand | `tv/<lang>/tv-*.png` |
| Header, tab "Header" (5244 × 2950 and 3840 × 1646), upload by hand | `header/<lang>/header-*.png`: iPhone in front of the iPad, Mac, Apple TV, watch |
| Header, tab "Search results" (same sizes), upload by hand | `header/<lang>/search-*.png`: iPhone, iPad and watch side by side |

`<lang>` is `de-DE` or `en-US`. The watch, Mac and TV pictures and the
headers live outside `screenshots/` because `fastlane deliver` uploads
that folder and only knows the sizes it already supports. Apple scales the
6.9" and 6.3" pictures down for every smaller iPhone.

The keywords deliberately contain no protected names of armed forces,
which Apple forbids (guideline 2.3.7). The vehicles carry fictional animal
names (Hermelin, Fuchs, Spitzmaus, Habicht, Keiler, Hirsch, Dachs, Igel,
Wolf) instead of model or maker names.

## Taking over the icon

The icon (a tank in side view on the horizon) is drawn by the design
system Horizont; the app neither draws nor scales it itself.
`tool/store/horizont_icons.py` copies the finished sets from
`icons/export/panzergefecht/` of a Horizont checkout into `icon/`, into the
icon sets for iOS, watch, macOS and Apple TV, into Android and `web/`, and
into the Play metadata:

```sh
python3 tool/store/horizont_icons.py ../horizont
```

## Regenerating the screenshots

Three commands, without a hand on a simulator:

```sh
tool/release.sh shots /tmp/raw           # every raw picture, about 15 minutes
tool/release.sh graphics /tmp/raw        # every store image (tool/store/compose.py)
python3 tool/store/landing.py /tmp/raw   # the device picture of the landing page
```

`tool/release.sh shots` builds one debug build per platform with
`--dart-define=SHOTS=true` and launches it once per scene and language,
the scene as a launch argument (`-SHOT_SCENE battle -SHOT_LANG en
-SHOT_OUT <file>`). The app walks into the scene by itself (start page,
waiting room, battle, defense, phone controller), waits until it has
settled and writes its own frame, without status bar or simulator chrome
(`lib/src/game/tank_game/shots.dart`). That makes 26 pictures, 13 scenes
each in German and English:

| Device | Scenes |
| --- | --- |
| iPhone 17 Pro Max, upright | `battle`, `defense`, `lobby`, `menu`, `pad` |
| iPad Pro 13", sideways | `battle`, `defense`, `room` |
| Apple TV 4K | `battle`, `defense` |
| Mac, window of 1440 × 900 points | `battle`, `defense`, `room` |

For single devices, name them: `tool/release.sh shots /tmp/raw ios ipad tv
mac`. For single pictures, a screenshot build also takes `-SHOT_MAP <n>`
(terrain, index into `MapTheme.all`: 4 = Bergwald, 5 = islands),
`-SHOT_TANK <n>` (vehicle, index into `TankType`: 8 = Igel, also when
locked) and `-SHOT_LAYOUT <n>` (defense map: 4 = Flussufer,
5 = Haarnadel). The script creates the simulators ("Store iPhone 6.9",
"Store iPad 13", "Store Apple TV") when they are missing; it expects
flutter-tvos in `~/flutter/flutter-tvos`. The watch app does not take its
own picture; its frame for the headers comes from `watch/`.

**Watch pictures** (`watch/<lang>/watch-0*.png`, 422 × 514) come from the
simulator "Apple Watch Ultra 4 (49mm)" and a build made with
`flutter-watchos build watchos --simulator --dart-define=SHOTS=true`, with
the scenes `menu`, `lobby`, `battle` and `defense`. The watch takes no
launch arguments (the engine aborts on them), and its preferences are one
JSON value under `flutterwatch.shared_preferences.store`. Scene and
language go in there with `xcrun simctl spawn <watch> defaults write
<container>/Library/Preferences/de.regetskcob.wargame.watchkitapp …`,
because cfprefsd overwrites a plist edited directly. The watch must be
awake (start it from the Simulator window first), or the app starts in the
background, draws nothing and the picture shows the start page. Then
`xcrun simctl launch`, wait for the scene, and `xcrun simctl io <watch>
screenshot` (with the time at the top). Run `compose.py` and `landing.py`
again afterwards; they put the watch into the headers and the landing
page.

**What `SHOTS=true` changes:** the own tank takes no damage, it stays day
without fog, the difficulty is easy (endless ammunition), everybody drives
the olive Hermelin unless `-SHOT_TANK` says otherwise, and a defense round
starts at wave `SHOT_WAVE` (default 3) with a grown base, 2000 coins and
the gun list open. In the battle and phone controller scenes both touch
sticks are drawn held. `tool/check_dart_defines.sh` keeps the mode out of
every release build.

**`compose.py`** sets each raw picture into a drawn device (iPhone, iPad,
MacBook, television) under a headline and a subline, all on the same olive
camouflage background, and writes both language sets for the App Store,
Mac App Store, Apple TV and Google Play, plus the headers (which the
landing page shows too) and the Play feature graphic. It needs Pillow
(`pip3 install --user pillow`).

## Answers in App Store Connect

**App Privacy:** no tracking. Collected and linked to the person, only for
app functionality:

- Contact info → email address (only who secures their account)
- Identifiers → user ID (the anonymous id of the guest account)
- User content → gameplay content (call sign, vehicle, scores)
- Usage data → product interaction (statistics, rounds, rating)

**Privacy manifests:** `PrivacyInfo.xcprivacy` in `ios/Runner`,
`ios/MessagesExtension`, `macos/Runner` and `tvos/Runner` give the reasons
for using `UserDefaults` (CA92.1, with the App Group 1C8F.1) and repeat the
answers above. When the collected data changes (for example with
purchases), update both the manifests and App Store Connect.

**Age rating:** cartoon or fantasy violence "frequent/intense" (tanks are
destroyed, infantry is run over), "none" everywhere else. That should
come out at 12+.

**Export compliance:** `Info.plist` already says
`ITSAppUsesNonExemptEncryption = false`, so the question does not come up.

**Category:** Games, subcategories Action and Strategy.

## TestFlight from the Mac

Builds are made and uploaded locally only, never in CI (a macOS minute
counts ten Linux minutes in a private repository, see
[CI minutes](../../docs/development.md#ci-minutes)). All three Apple
platforms share the bundle id, the team (`apple/Signing.xcconfig`) and the
App Store entry; the build number is the one in `pubspec.yaml`.

| What | Command |
| --- | --- |
| iOS with the watch app | `tool/release.sh ios --upload` |
| Apple TV / Mac | `tool/release.sh tvos --upload` or `macos --upload` |
| Texts and screenshots | in `ios/`: `bundle exec fastlane ios metadata` |

Without `--upload` the checked archive only lands in the Xcode Organizer.
Signing uses the Apple account signed in to Xcode. Before any upload, run
the [release test plan](../../docs/release-test-plan.md).

### One-time setup

1. **Create the app:** App Store Connect > Apps > New App, platform iOS,
   name "Panzergefecht", language German, bundle id
   `de.regetskcob.wargame`, SKU for example `panzergefecht`.
2. **API key:** App Store Connect > Users and Access > Integrations > App
   Store Connect API > generate a key with the **Admin** role (only that
   lets Xcode fetch certificate and profile itself). The `.p8` file can be
   downloaded only once.
3. **The key on the Mac** (only for `fastlane ios metadata`, never in the
   repository): put the `.p8` somewhere like
   `~/.appstoreconnect/private_keys/`, then set `ASC_KEY_ID` (the key id),
   `ASC_ISSUER_ID` (the issuer id above the key list) and `ASC_KEY_PATH`
   (the path to the `.p8`).
4. **Distribution certificate** in the Mac's keychain: **always needed for
   tvOS**, because flutter-tvos signs the engine with it, and Apple rejects
   an unsigned engine (ITMS-91065). Xcode creates it under Settings >
   Accounts > Manage Certificates.
5. **tvOS and macOS in App Store Connect:** add both under "Add Platform"
   in the existing Panzergefecht entry, or TestFlight rejects the uploads.

After that, every upload shows up under TestFlight once Apple has
processed it (usually 10 to 30 minutes). For external testers Apple reviews
the first build once; the texts for that are in
`metadata/<lang>/testflight.txt`.

## Open before submission

Status of the maintainer's account; a fork goes through the same steps.

1. **Set up as above**, then run `bundle exec fastlane ios metadata` in
   `ios/`.
2. **By hand in App Store Connect:** App Privacy (see above), age rating,
   price (free), then submit for review.
3. **Play the TestFlight build on a real iPhone** (release test F11.1 and
   R8): the simulator only runs debug builds, and a release build can fail
   where debug works, as the weather drawing once did on Android.

## Universal Links

Room links (`https://panzergefecht.de/play/?room=CODE`) and pairing links
(`?pad=CODE`) open the app when it is installed, also from the iPhone
camera. The app asks for `applinks:panzergefecht.de`
(`ios/Runner/Runner.entitlements`, team 86HB5U6788). Apple only reads the
association file at the root of the domain; the site is that root, and
`site/hugo.toml` mounts
[`apple-app-site-association`](apple-app-site-association) from this
folder into `.well-known/`, so every deploy of the `pages` workflow
carries it. Check after the deploy:

```sh
curl -s https://panzergefecht.de/.well-known/apple-app-site-association
curl -s https://app-site-association.cdn-apple.com/a/v1/panzergefecht.de
```

Links shared before the move to panzergefecht.de point to
`https://www.regetskcob.de/wargame/…`. The app still asks for
`applinks:www.regetskcob.de` so they keep opening it; their association
file (paths `/wargame/*`) lives in the maintainer's website repository at
`static/.well-known/apple-app-site-association`. A fork drops that domain.

Apple's CDN can take a day to pick up a change, and iOS fetches the file
when the app is installed or updated.
