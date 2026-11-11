# Development

The contributor's handbook: what you need installed, how to run the game
locally, how to test it and what to check before a pull request. The later
sections go deeper: the database, the release scripts, deploying your own
copy, the CI workflows, the landing page and fonts. For gameplay rules see
[gameplay.md](gameplay.md), for rooms and the message budget
[netcode.md](netcode.md), for the platforms [platforms.md](platforms.md),
and for running a fork under your own name [forking.md](forking.md).

## Contents

- [Prerequisites](#prerequisites)
- [First run](#first-run)
- [Before a pull request](#before-a-pull-request)
- [Tests](#tests)
- [Texts in two languages](#texts-in-two-languages)
- [Database](#database)
- [Release scripts](#release-scripts)
- [Deploying](#deploying), with [CI workflows](#ci-workflows) and
  [CI minutes](#ci-minutes)
- [Landing page](#landing-page)
- [Fonts](#fonts)
- [Device QA](#device-qa)

## Prerequisites

| Tool | Needed for |
| --- | --- |
| [Flutter](https://flutter.dev) 3.47 (stable, Dart 3.13) | everything; CI pins 3.47.0 |
| [Supabase CLI](https://supabase.com/docs/guides/local-development) 2.x and Docker | a local backend and the tests tagged `supabase` |
| Xcode | iOS, macOS, Apple TV and Apple Watch builds |
| Android SDK and Java 17 | Android and Wear OS builds |
| [Hugo](https://gohugo.io) extended (CI uses 0.154.5) and Go | the landing page in `site/` |
| Python 3 with Pillow | the store image tools in `tool/store/` |
| [flutter-tvos](https://github.com/fluttertv/flutter-tvos), [flutter-watchos](https://github.com/flutterwatch/flutter-watchos) | only Apple TV and Apple Watch builds, see [platforms.md](platforms.md) |

Only Flutter is needed to run the game in a browser and to run the tests.
`tool/werkbank/bin/werkbank doctor` lists which of the tools and keys it
finds.

## First run

```sh
flutter pub get
supabase start   # local stack, API on port 54621, applies the migrations
flutter run -d chrome \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54621 \
  --dart-define=SUPABASE_KEY=<publishable key printed by supabase start> \
  --dart-define=ROOM=dev
```

Start it twice to play against yourself: games with the same `ROOM` meet in
the same room. Without the two Supabase defines a build talks to the live
game's project (the defaults in
[`lib/src/app/env.dart`](../lib/src/app/env.dart)), whose message budget
every player shares, so develop against the local stack or your own
project. Without any backend the game still starts, and solo play works
offline.

All build flags live in `lib/src/app/env.dart`: `SUPABASE_URL`,
`SUPABASE_KEY`, `ROOM`, `ACCOUNTS` (sign-in on or off), `WEB_URL` (the
address room links point to), `MAX_PILOTS` and `REALTIME_BUDGET` (see
[Rooms and room sizes](netcode.md#rooms-and-room-sizes)).

## Before a pull request

```sh
tool/release.sh verify --quick
```

This is the gate CI runs on a pull request: the folder layout, `dart
format`, `flutter analyze`, every test except the `supabase` tag, and a
line coverage of at least 75 %. It runs from any directory. Locally it
also runs the golden tests, which only match on macOS (see
[Goldens](#goldens)).

The full `tool/release.sh verify` adds the web, landing page, iOS, macOS,
Android and Wear OS builds without store signing. It is worth the time
when a change touches `pubspec.*`, `ios/`, `android/`, `tvos/`, the watch,
assets or plugins, because CI does not build the native apps on a pull
request.

Code, comments, commit messages and docs are in English; every visible
text exists in German and English (see
[Texts in two languages](#texts-in-two-languages)). `CHANGELOG.md` and
`CHANGELOG.de.md` change together in the same commit. Comments explain
*why*. When behaviour changes, update `docs/` and, for a highlight, the
README.

## Tests

`test/` mirrors `lib/src/`; shared fakes, among them `LoopbackNet`, are in
[`test/helpers/fakes.dart`](../test/helpers/fakes.dart). Tags in
[`dart_test.yaml`](../dart_test.yaml) keep slow or special tests out of the
normal run:

| Tag | What | How to run |
| --- | --- | --- |
| `golden` | pixel pictures of the menus | in `tool/release.sh verify` on a Mac; never in CI, because fonts render differently on Linux |
| `supabase` | Broadcast, Presence, the `scores` table and the phone controller against a real stack | `supabase start`, then `flutter test --tags supabase` |
| `balance` | hundreds of solo rounds per difficulty, skipped by default | `flutter test test/game/balance_sim_test.dart --run-skipped`, see [Balance](gameplay.md#balance) |
| `benchmark` | a long defense session up to wave 50, skipped by default | see L3 in [release-test-plan.md](release-test-plan.md) |

### Coverage

The `pages` and `ci` workflows and `tool/release.sh verify` run the tests
with `--coverage`, then `dart run tool/coverage.dart --min 75` fails below
75 % of the lines. The tool leaves generated code out, prints the files
with the most uncovered lines, and lists the files no test loads at all
(the app shell, the Apple TV split screen, the web-only room code), which
the share does not count.

### Time in tests

The game logic reads the time through `clock.now()` (package `clock`),
never `DateTime.now()`, so a test can run a round on a fake clock with
`withClock`: the closing zone, the gentle start and the waves then follow
the simulated seconds. Widget tests already run on such a clock, so their
`startedAt` comes from `clock.now()` as well.

### Realtime budget and compatibility

These tests guard the message budget of
[Realtime limits](netcode.md#realtime-limits) and the wire contract with
older clients. All of them run without a server.

| Test | Checks |
| --- | --- |
| `test/net/message_budget_test.dart` | plays real rounds on a `TankGame`, counts what goes onto the channel and works out a room's load the way Realtime counts it; its skipped tests are targets still out of reach |
| `test/net/pad_budget_test.dart` | the same for a paired phone controller, and the duel on lanes |
| `test/net/presence_throttle_test.dart` | no burst of presence updates gets near Realtime's limit (fake clock) |
| `test/game/room_capacity_test.dart` | the room limit and what rooms claim of the budget |
| `test/net/pad_screen_test.dart` | what phones claim, and the lanes |
| `test/ui/widgets/rooms_busy_test.dart` | what the start page and the room list show while the budget is full |
| `test/db/server_status_test.dart` | a server that refuses with 402 or cannot be reached |
| `test/db/rpc_contract_test.dart` | reads the migrations and every `rpc` call of the game: each function exists, knows every parameter and may be run by a signed-in player |
| `test/net/wire_format_test.dart` | event names and the fields older clients read stay, so a room of mixed versions keeps working |

The budget tests also check that `GameConfig.roomLoad` and
`GameConfig.padLoad` are not below what rooms and phones measurably send.

### Smoke tests

Three tests play whole rounds without a server and only ask that nothing
throws:

- [`test/game/smoke_test.dart`](../test/game/smoke_test.dart) runs every
  mode on every CPU level with the local tank driving, firing and setting
  off every item, and a defense round with every gun, trench and aircraft
  on both sides.
- [`test/game/two_player_smoke_test.dart`](../test/game/two_player_smoke_test.dart)
  puts two real games in one room through `LoopbackNet`, so round start,
  tank states, deaths, the host's defense and flag state and the replay
  cross the wire format.
- [`test/ui/overlays_smoke_test.dart`](../test/ui/overlays_smoke_test.dart)
  builds the waiting room, countdown, HUD, spectator view, round end and
  closed room from a real game in its phase, on a desktop and a phone, in
  German and English, with the real fonts loaded, so a layout overflow is
  one a player would see.

Two things matter when driving a `TankGame` in a test. `update` runs the
whole component tree, but tanks the host spawns mid-round load
asynchronously and only mount if the test yields between frames (`await
Future<void>.delayed(Duration.zero)`). And inside `testWidgets`, game
changes that start timers belong in `tester.runAsync`. The balance
simulation awaits once per simulated frame for the same reason: otherwise
new shells and tanks never finish loading.

### Goldens

[`test/ui/goldens_test.dart`](../test/ui/goldens_test.dart) compares the
welcome, the choice of mode and the solo waiting room on a phone, a tablet
held sideways and a desktop window, plus the legal links, against pictures
in `test/ui/goldens/`. The game has only a dark theme, so only that is
tested. After an intended change to the menus, renew them and look at
every picture before committing:

```sh
flutter test test/ui/goldens_test.dart --update-goldens
```

## Texts in two languages

Every visible text comes from `tr(de, en)`
([`lib/src/l10n/l10n.dart`](../lib/src/l10n/l10n.dart)) at build time.
Picking another language rebuilds the whole app below `MaterialApp`
(`LanguageRebuild` in `lib/src/ui/widgets/language_rebuild.dart`), const
widgets and covered pages included, so no widget needs to listen to
`L10n.lang` itself. A text kept in a field or a `late final` outside
`build` would still miss the change: call `tr` in `build`.

## Database

Supabase is the only backend. The schema is a numbered series of
migrations, `supabase/migrations/NNNN_name.sql` (`0001` to `0022` today).
`supabase start` applies them to the local stack, and `supabase db reset`
applies them again from scratch. Rules for a new migration:

- Row level security on every table. Functions that write run as
  `security definer` with an empty `search_path` and are revoked from
  `public` and `anon` unless guests need them.
- Scores only change through the RPC `record_round`; clients never write
  them directly.
- The game must keep working against a database that lacks the newest
  migration (older deploys, local stacks): catch the missing function or
  column and degrade.
- `test/db/rpc_contract_test.dart` fails when a client call no longer
  matches a function.

The services that talk to the database are in `lib/src/db/`.

### Regenerating the typed database models

`lib/src/db/supabase_schema.g.dart` is generated by `supabase_typegen` from
`supabase/schema.json`, a snapshot of the postgres-meta introspection
document. After changing a migration, update the snapshot to match and
regenerate:

```sh
dart run supabase_typegen \
  --output lib/src/db/supabase_schema.g.dart \
  --import package:supabase_flutter/supabase_flutter.dart \
  < supabase/schema.json
```

Columns added to a table after it was created (the statistics, `rating`,
`xp` and `rated_rounds` on `scores`, `style` on `players`) read with a
default in `supabase_schema.g.dart` (`?? 0`, `?? 1000` for the rating), so
the game survives a database that has not been migrated yet. The generator
drops these fallbacks: put them back after regenerating.

The types can also come straight from a database instead of the snapshot.
The Supabase CLI (2.120 or newer) generates Dart, with `--local` for the
running local stack or `--project-id <ref>` for a hosted project after
`supabase login`:

```sh
supabase gen types --lang dart --local > lib/src/db/supabase_schema.g.dart
```

The CLI runs the `supabase_typegen` dev dependency of the package it is
called from. On an older CLI, call the generator yourself:

```sh
dart run supabase_typegen --local --output lib/src/db/supabase_schema.g.dart
```

## Release scripts

Maintainer tooling. Every check, release build and store step starts from
one script, `tool/release.sh`; run it without arguments for its help.
Nothing leaves the machine without `--upload`.

| Command | What |
| --- | --- |
| `tool/release.sh verify --quick` | layout, format, analyze, tests without the `supabase` tag, coverage floor of 75 % |
| `tool/release.sh verify` | the same, then the web, landing page, iOS, macOS, Android and Wear OS builds without store signing |
| `tool/release.sh release [--dry-run] [--upload]` | the whole release: preflight (clean `main`, changelog, release texts, verify), every store build below, tag `v<version>`, report in `build/release/` |
| `tool/release.sh changelog\|notes [--draft]` | check or draft the changelogs and the TestFlight and Play texts of this build |
| `tool/release.sh site panzergefecht [--live]` | build the landing page; `--live` starts the `pages` workflow |
| `tool/release.sh android phone\|wear [--upload <track>] [--metadata] [--completed]` | signed App Bundle to `build/release/`, upload through werkbank (`tool/release_android.sh`) |
| `tool/release.sh ios [--upload]` | App Store archive with the watch app inside, to the Xcode Organizer (`tool/archive_ios.sh`) |
| `tool/release.sh tvos\|macos [--upload]` | the same for the Apple TV or the Mac app (`tool/archive_apple.sh`) |
| `tool/release.sh upload <path.xcarchive>` | send a checked archive to App Store Connect (werkbank `upload-apple`) |
| `tool/release.sh shots <raw dir> [ios] [ipad] [tv] [mac] [atv]` | raw store pictures from the simulators, and with `atv` from an Android TV emulator (`tool/store_shots.sh`) |
| `tool/release.sh graphics <raw dir>` | store images from the raw pictures (`tool/store/compose.py`) |

The folder layout follows a shared standard of the maintainer's app
repositories, [`tool/werkbank/STANDARD.md`](../tool/werkbank/STANDARD.md).
`tool/werkbank/` is a vendored copy of that private repository and is not
edited here; `tool/werkbank.conf` holds this project's settings, and
`CLAUDE.md` lists where the project departs from the standard and why. The
version, the keytool and signature checks and the store simulators come
from the werkbank (`werkbank version`, `wb_check_signature`, `werkbank
sim`); the watch embedding, the Supabase URL check, the dart-define check
in Xcode and the uploads stay in the project's own scripts.
[`tool/release_env.sh`](../tool/release_env.sh) gives them their shared
defines (accounts on, and `SUPABASE_URL`, `SUPABASE_KEY`, `WEB_URL`,
`MAX_PILOTS`, `REALTIME_BUDGET`, `PURCHASES` when set in the environment),
the Supabase address the build must carry, and the Apple team of
`apple/Signing.xcconfig`.

Store texts and pictures are described in
[`store/ios/README.md`](../store/ios/README.md) and
[`store/android/README.md`](../store/android/README.md), and what has to
hold before an upload in [release-test-plan.md](release-test-plan.md).

## Deploying

The web game runs on GitHub Pages and talks to a hosted Supabase project;
there is no server of its own. To run your own copy (app ids, domain and
signing are in [forking.md](forking.md)):

1. Create a Supabase project, apply the migrations and allow anonymous
   sign-ins (Authentication, Sign In / Providers):

   ```sh
   supabase link --project-ref your-project-ref
   supabase db push
   ```

   The game keeps working against a database that lacks the newer
   migrations, but rating, experience, badges and the saved call sign only
   work once they are applied. Push the migrations before the game.

   Accounts are switched on by the build flag `--dart-define=ACCOUNTS=true`,
   which the `pages` workflow sets when the repository variable `ACCOUNTS`
   is `true`. Without it everybody plays as a guest. For accounts the
   project needs, in the Supabase dashboard:

   - Authentication, URL Configuration: the URL of the game as Site URL,
     and the same URL with `/**` as redirect URL, so mail links lead back
     to the game.
   - Sign In / Providers: anonymous sign-ins, e-mail and "Allow manual
     linking" switched on.
   - Authentication, Emails: your own SMTP server; without one Supabase
     only mails the members of the project team, a few mails an hour. Then
     the German templates from `supabase/templates` for "Magic Link" and
     "Change Email Address", which also carry the code to type in.
   - Optional GitHub and Google logins: an OAuth app at the provider with
     the callback `https://your-project-ref.supabase.co/auth/v1/callback`,
     entered under Sign In / Providers. The game only offers the logins the
     project has switched on.

2. In the GitHub repository, set Pages to the "GitHub Actions" source and
   add the repository variables (Settings, Secrets and variables, Actions,
   Variables) `SUPABASE_URL`, `SUPABASE_KEY` (the publishable key) and, for
   accounts, `ACCOUNTS` set to `true`. `MAX_PILOTS` and `REALTIME_BUDGET`
   are optional: without them the build assumes the Pro plan (4 and 400);
   on the free plan set 2 and 80, see
   [Rooms and room sizes](netcode.md#rooms-and-room-sizes).
3. Push to `main`. The `pages` workflow builds the landing page (Hugo,
   `site/`) into the root of the site and the game into `play/` below it,
   with the base path GitHub Pages reports, and publishes both. Without the
   variables the build falls back to the project in
   `lib/src/app/env.dart`. A `SUPABASE_URL` or `SUPABASE_KEY` that is not
   an address or key (say, several `--dart-define`s glued into one quoted
   value) falls back the same way and logs why, and an iOS build in Xcode
   stops on it (`tool/check_dart_defines.sh` in the Flutter build phase).

To build the web game by hand:

```sh
flutter build web --base-href /play/ \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_KEY=sb_publishable_...
```

### CI workflows

| Workflow | Runs | Runner |
| --- | --- | --- |
| `pages` | every push to `main`: layout, format, analyze, tests with coverage, web and landing page build, deploy, all in one job | Linux |
| `ci` | pull requests: the same checks without a deploy; by hand (`gh workflow run ci -f apple=true -f android=true -f watchos=false`): the native builds | Linux, macOS for Apple |
| `build-status` | after `pages` or a manual `ci` on `main` | Linux, single core (`ubuntu-slim`) |

GitHub only mails when a workflow fails, not when it recovers.
`build-status` fills that gap: when `ci` or `pages` fails on `main`, it
opens an issue labelled `build-failed` (one per workflow; later failures
add a comment), and the next green run closes it. Watchers of the
repository get a mail for both.

CI only validates; nothing is released from it. Store builds are made and
uploaded on the maintainer's Mac with `tool/release.sh` (see
[Release scripts](#release-scripts)), because a TestFlight run on a macOS
runner would cost some 250 minutes per platform. The signing keys stay on
that Mac: the Apple account signed in to Xcode, `android/key.properties`
with the upload key, the Play service account in
`android/play-service-account.json` and, for the store texts, an App Store
Connect API key. The repository holds no Actions secrets.

### CI minutes

A private repository bills every runner minute against the plan: GitHub
Pro includes 3,000 minutes and 1 GB of artifact storage a month, a macOS
minute counts about ten Linux minutes, and each job is rounded up to the
whole minute. A push to `main` once cost about 165 of those minutes (iOS,
Mac, watch and Android builds, then testing and building again for Pages),
far beyond the plan at some 85 pushes a month. The workflows now keep a
push near ten Linux minutes:

- One Linux job checks and deploys a push to `main`; native builds run
  only by hand.
- A newer push cancels the run still going (`cancel-in-progress`).
- The Flutter SDK and pub packages come from the Actions cache.
- Every job has a `timeout-minutes` (the default would bill six hours of a
  hung macOS job).
- The site artifact is kept for one day.

Keep the account's Actions budget (Settings, Billing and licensing, Budgets
and alerts) at US$0 with "Stop usage when budget limit is reached": a month
that runs out of minutes then stops the workflows instead of billing, and
GitHub mails at 90 and 100 % of the included minutes. The Pages site stays
public and free when the repository is private. Public repositories run on
standard runners for free, so there these limits matter less.

## Landing page

`site/` is a small Hugo site, the page in front of the game at the root of
<https://panzergefecht.de/>. It is built from Horizont, the maintainer's
design system (<https://github.com/regetskcob/horizont>, web guide in its
`docs/web.md`), as one of its "Feldseite" pages:

- the head with the lockup and a quiet nav;
- a hero with a "Kennung" (section mark), the headline in Literata and
  "Jetzt spielen" as the one primary button;
- every device in one picture on the horizon line (`devices.png` and
  `devices-narrow.png` in `site/assets/header/<lang>/`, drawn by
  `tool/store/landing.py` from the raw shots of `tool/release.sh shots`);
- numbered sections `02 — Modi`, `03 — Geräte`, `04 — Beta` and
  `05 — Fair`, with facts in mono and the store screenshots in Horizont's
  device frames, which open full size in its lightbox;
- the foot with the legal links.

The page stays dark on Panzergefecht's own "Gelände" neutrals
(`data-product="panzergefecht" data-theme="dark"` on `<html>`); the signal
yellow belongs to the play button alone.

**Horizont as a Hugo module.** It is pinned to a tag in `site/go.mod` and
`site/go.sum`. `site/hugo.toml` mounts its tokens, icon names, CSS,
partials (`layouts/_partials/horizont/`), shortcodes and fonts as its
`docs/web.md` says. The CSS is tokens, components, then
`site/assets/css/site.css` with only the page's own layout, every value a
Horizont variable. Layouts use the module's partials (`horizont/feld/*`,
`device.html`, `facts.html`, `kennung.html`, `badge.html`,
`lightbox.html`) and never copy their HTML. Hugo fetches the module with
Go (`brew install go` is enough locally). To move to a newer Horizont, read
its CHANGELOG, then:

```sh
cd site && hugo mod get github.com/regetskcob/horizont@vX.Y.Z
```

and check the page in both languages and at 375 px.

**Texts and pictures come from the App Store listing.** Name, subtitle,
promotional text and description come from `store/ios/metadata/<lang>/`,
the shots from `store/ios/screenshots/`, `mac/`, `tv/` and `watch/`
(mounts in `site/hugo.toml`). The store images carry a caption and a drawn
device, so `site/layouts/_partials/shot.html` cuts the bare screen out of
them (the rectangles in `site/data/screens.yaml` follow
`tool/store/compose.py`; measure again if its layout changes) and sets it
in Horizont's device frame, resized to WebP at build time. The description
is parsed, so its layout matters:

1. an opening paragraph, the text of `02 — Modi`;
2. sections whose first line is a heading in capitals; only the first is
   used, its `• Name: text` lines are the ways to play, and the page shows
   each one's first sentence as a fact;
3. loose paragraphs: the pledge and the disclaimer make `05 — Fair`, the
   rest goes under the foot.

Only the page's own words live in `site/i18n/`, among them the devices
section, since the store description is the iOS app's; `platformsNote`
says what is out today and is the place to update when a platform ships.
`04 — Beta` lists the ways into the apps in the order they have to be
taken: the store pages once `[params.stores]` in `site/hugo.toml` has
them, then TestFlight, then for Android the tester group before the closed
test on Google Play. German sits at the root, English under `en/`; a first
visit follows the browser language, as the game does. The favicons are the
web game's (`web/`).

**The play button** leads to `play/`, the game's start page. On the press
the page lays the game's launch screen (ground and tank) over itself, the
same picture `web/index.html` starts with, so the switch does not flash;
pointing at the button already prefetches the game's scripts. Links that
used to open the game at the root (room and pairing links of older apps,
sign-in mails with `?code=`, home screen shortcuts) are passed on to
`play/` before the page draws, so they keep working.

**Other pages.** Impressum, privacy and licences sit at `/impressum/`,
`/datenschutz/` and `/lizenzen/`; the licence page links the `NOTICES`
file of the web build, which holds the licences of every package and the
engine. In the game, "Lizenzen" opens Flutter's licence page, where
`registerHorizontLicenses()` adds the fonts' licences. `/changelog/` shows
the latest store versions from the changelogs. `/support/` (and
`en/support/`) is the support URL of the store listings. With no server of
its own, its form sends nothing: it writes topic, device, call sign and
message into a mail to `params.supportMail` and opens it in the visitor's
mail app, so no form service sees what people type.

**Maintenance switch.** For a short move, such as the one to a new domain,
`maintenance = true` under `[params]` in `site/hugo.toml` puts the
maintenance page (`site/layouts/_partials/maintenance.html`, texts
`maintenance-*` in `site/i18n/`) in place of every page, and the `pages`
workflow writes it under `play/` instead of the game, so room links and
sign-in mails land on it too. Impressum, privacy and licences stay. Set it
back to `false` and push to bring the site and the game back.

**Running it locally:**

```sh
hugo server --source site          # http://localhost:1313/
```

The play button needs the game next to it; for the whole site as
deployed:

```sh
flutter build web --base-href /play/
hugo --source site --baseURL http://localhost:8000/ -d /tmp/site
cp -R build/web /tmp/site/play
python3 -m http.server -d /tmp/site 8000
```

## Fonts

The game uses the four typefaces of the design system
[Horizont](https://github.com/regetskcob/horizont): Mona Sans for everything
you operate, Mona Sans Display Expanded in capitals for headlines,
Monaspace Argon with tabular figures for every value that is measured
(scores, times, codes, the HUD's marks), and Literata for long reading text.
The menus follow Horizont's soft style: section labels (Kennungen) and
counts beside a label are in Mona Sans. They come with the
`horizont` package (`pubspec.yaml`, pinned to a tag) together with their
licences (`registerHorizontLicenses()`), so the app bundles no font of its
own. `GameType` in `lib/src/ui/theme.dart` names the styles the game uses;
widgets never set a `fontFamily` themselves.

Tests that measure text load the real fonts with `loadHorizontFonts()` from
`package:horizont/testing.dart`. The store tool `tool/store/compose.py`
finds the same files through `tool/store/horizont_fonts.py`, so run
`flutter pub get` before it.

Horizont cuts its fonts down to Latin with extensions, punctuation and the
few marks set as text (about 0.85 MB, 0.48 MB gzipped), because the browser
build loads every font before its first frame. A character outside that
range falls back to the system font or Noto; the range is set in
Horizont's `tool/subset_fonts.py`, so a wider one goes there.

## Device QA

Maintainer measurements on a physical device, kept so they can be
repeated. Two things only a real device shows: whether frames fit the
display's budget, and what the sound costs. The reference is an iPad Pro
11" (2018, A12X, ProMotion 120 Hz). The repeatable frame test is L4 in
[release-test-plan.md](release-test-plan.md)
(`integration_test/frame_timing_test.dart`).

**Multi-touch.** `test/ui/widgets/touch_controls_multitouch_test.dart`
puts five fingers on the twin sticks at once: both thumbs on the sticks,
fingers on the special weapon, the aim assist and the field, lifted in odd
orders with one cancelled, a thumb sliding from a stick over the buttons,
a second thumb taking a stick over, the controls taken away under all
five. `test/ui/controller_view_test.dart` does the same on the phone
controller while the screen rebuilds its controls under the fingers, and
checks that nothing is held down afterwards. On 2026-10-11 the same cases
passed as a (not kept) `integration_test` with the real game in a
`GameWidget` on the iPad. The fingers are injected into Flutter there, so
the operating system's own touch handling is the one part a human hand
still has to try.

**Frame timings, the earlier method.** Before the integration test, a
temporary scene in `lib/src/game/tank_game/shots.dart` played a round by
itself (solo, defense forced to wave 30 with the base kept alive, or
capture the flag 3 against 3 with CPU crews), read `FrameTiming` through
`SchedulerBinding.addTimingsCallback` and appended build and raster
p50/p95 every five seconds to `tmp/perf.log` in the app's container. It
ran as a **release** build with a temporary define that lets
`Env.loadShots` read the scene (`SHOTS=true` itself is refused for Release
by `tool/check_dart_defines.sh`, and it also makes the own tank
invulnerable and the weather fair). Install and start with `xcrun
devicectl device install app` and `device process launch
--terminate-existing … -SHOT_SCENE <scene>`, fetch the log with
`devicectl device copy from --domain-type appDataContainer
--domain-identifier <bundle id> --source tmp/perf.log`, and see the screen
with `xcrun devicectl device capture screenshot`.

Pitfalls:

- A profile or debug build makes iOS ask whether the app may look for
  devices on the local network (for Flutter's tools). Until somebody
  answers on the device, the app stays inactive and draws nothing, also
  after reinstalling.
- The iPad must not lock.
- The engine now and then hands over a batch of timings late, so a window
  can show 100 frames too few while a persistent frame callback still
  counts 600. Count those too before calling it a stutter.
- Runs of the same scene differ by several frames a second, so compare in
  alternating series (sound on, muted, three times each), not single runs.

Results on the iPad (release build, 120 Hz, budget 8.3 ms):

| Scene | fps | build p95 | raster p95 | frames > 16.7 ms |
| --- | --- | --- | --- | --- |
| Capture the flag 3 against 3, 10 min, 2 rounds, 24 carries, 16 respawns | 120 | 2.9 ms | 6.0 ms (worst window 9.6) | 0.1 % |
| Defense wave 30, sound on, before | 95 | 6.0 ms | 14.1 ms | 47 % |
| Defense wave 30, muted, before | 108 | 4.5 ms | 12.0 ms | 26 % |
| Defense wave 30, sound on, after | 95 | 5.7 ms | 14.4 ms | 47 % |
| Defense wave 30, muted, after | 105 | 4.7 ms | 12.3 ms | 31 % |

"Before" and "after" refer to the sound rework. In wave 30 the mixer admits
about 15 sounds a second. Before, restarting a voice took a p95 of 4.4 s
and up to 19 s, almost all of it in `stop()`, which winds an AVPlayer back
through iOS's media daemon; the own shots were heard seconds late or not
at all. After (`VoiceTraffic` with three own voices, no position polling,
`EngineThrottle`), the p50 stays at 5 ms, platform calls fell from 40 to 30
a second, and a sound that is not through within 120 ms is left out
instead of coming late. No errors, and no players leak (the count stays at
the voices loaded at start). What remains is the cost of AVPlayer itself,
about 10 frames a second in wave 30; only a mixing engine instead of one
AVPlayer per voice would remove it.
