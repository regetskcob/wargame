# Development

## Tests

`test/net/message_budget_test.dart` plays real rounds on a `TankGame` and
counts what would go onto the channel, then works out the load of a room
the way Realtime counts it; its skipped tests are the targets still out
of reach. `test/net/pad_budget_test.dart` does the same for a paired
phone controller, `test/net/presence_throttle_test.dart` checks that no
burst of presence updates gets near Realtime's limit, both on a fake
clock, and the duel on lanes. `test/game/room_capacity_test.dart`
covers the room limit and what rooms claim of the budget,
`test/net/pad_screen_test.dart` what phones claim and the lanes,
`test/ui/widgets/rooms_busy_test.dart` what the start page and the room
list show while the budget is full,
`test/db/server_status_test.dart` a server that refuses with 402 or
cannot be reached. Two more catch breaking changes before a deploy:
`test/db/rpc_contract_test.dart` reads the migrations and every `rpc`
call of the game and checks that the function exists, knows every
parameter and may be run by a signed in player;
`test/net/wire_format_test.dart` keeps the event names and the fields
older clients read, so a room of mixed versions keeps working. The budget
tests also check that `GameConfig.roomLoad` and `GameConfig.padLoad` are
not below what rooms and phones measurably send. All of them run without a server; see
[Realtime limits](netcode.md#realtime-limits).

The game logic reads the time through `clock.now()` (package `clock`),
never `DateTime.now()`, so a test can run a round on a fake clock with
`withClock`: the closing zone, the gentle start and the waves then follow
the simulated seconds. Widget tests run on such a clock already, so their
`startedAt` comes from `clock.now()` too. `test/game/balance_sim_test.dart`
uses it to play hundreds of solo rounds against each difficulty and is
skipped in the normal run (tag `balance` in `dart_test.yaml`); see
[Balance](gameplay.md#balance). Each simulated frame awaits once, or new
shells and tanks never finish loading and no shell of the player lands.

`test/ui/goldens_test.dart` compares the welcome, the choice of mode, the
solo waiting room and the sender over the legal links, on a phone and a
desktop, with pictures under `test/ui/goldens/`, in the dark theme only,
since the game has no light one. Fonts render differently on Linux, so the
tag `golden` stays out of CI and runs in `tool/verify.sh` on the Mac. After
a wanted change of the menus, renew them with
`flutter test test/ui/goldens_test.dart --update-goldens` and look at the
pictures before committing.

Three smoke tests play whole rounds without a server and only ask that
nothing throws. `test/game/smoke_test.dart` runs every mode on every bot
level with the local tank driving, firing and setting off every item, and
a defense round with every gun, trench and aircraft on both sides.
`test/game/two_player_smoke_test.dart` puts two real games in one room
through `LoopbackNet` (`test/helpers/fakes.dart`), so round start, tank
states, deaths, the host's defense and flag state and the replay cross
the wire format. `test/ui/overlays_smoke_test.dart` builds the waiting
room, countdown, HUD, spectator view, round end and closed room from a
real game in its phase, on a desktop and a phone, in German and English,
with the bundled Roboto loaded so a layout overflow is one a player would
see. Two things matter when driving a `TankGame` in a test: `update`
runs the whole component tree, but tanks the host spawns mid-round load
asynchronously and only mount if the test yields between frames
(`await Future<void>.delayed(Duration.zero)`); and inside `testWidgets`
game changes that start timers belong in `tester.runAsync`.

The `pages` workflow and `tool/verify.sh` run the tests with `--coverage` and
`dart run tool/coverage.dart --min 75` fails below 75 % of the lines.
It leaves generated code out, prints the files with the most uncovered
lines, and lists the files no test loads at all (the app shell, the
Apple TV split screen, the web-only room code), which the share does not
count.

The integration smoke test exercises Broadcast, Presence, and the typed
`scores` table against the local stack:

```sh
supabase start
flutter test
```

## Device QA

Two things only a real device shows: whether frames fit the display's
budget, and what the sound costs. The physical reference is an iPad Pro
11" (2018, A12X, ProMotion 120 Hz).

**Multi-touch.** `test/ui/widgets/touch_controls_multitouch_test.dart`
puts five fingers on the twin sticks at once: both thumbs on the sticks,
fingers on the special weapon, the aim assist and the field, lifted in odd
orders with one cancelled, a thumb sliding from a stick over the buttons,
a second thumb taking a stick over, the controls taken away under all
five. `test/ui/controller_view_test.dart` does the same on the phone
controller while the screen rebuilds its controls under the fingers, and
checks that what goes out afterwards holds nothing down. On 2026-10-11 the
same cases ran as a (not kept) `integration_test` with the real game in a
`GameWidget` on the iPad's own frames and passed. There the fingers are
injected into Flutter, so the operating system's own touch handling is
the one part a human hand still has to try.

**Frame timings.** There is no committed measuring mode. The way that
worked: a temporary scene in `tank_game/shots.dart` that plays a round by
itself (solo, defense forced to wave 30 with the base kept alive, or
capture the flag 3 against 3 with CPU crews), reads `FrameTiming` through
`SchedulerBinding.addTimingsCallback` and appends one line every five
seconds with build and raster p50/p95 to `tmp/perf.log` in the app's
container. Build it as a **release** build with a temporary define that
lets `Env.loadShots` read the scene (`SHOTS=true` is refused for Release
by `tool/check_dart_defines.sh`, and it also makes the own tank
invulnerable and the weather fair), install and start it with
`xcrun devicectl device install app` and `device process launch
--terminate-existing … -SHOT_SCENE <scene>`, and fetch the log with
`devicectl device copy from --domain-type appDataContainer
--domain-identifier de.regetskcob.wargame --source tmp/perf.log`.
`xcrun devicectl device capture screenshot` shows what the screen shows.
Pitfalls: a profile or debug build makes iOS ask whether the app may look
for devices on the local network (for Flutter's tools); until somebody
answers on the device the app stays inactive and draws nothing, also
after reinstalling. The iPad must not lock. And the engine now and then
hands over a batch of timings late, so a window can show 100 frames too
few while the frames counted by a persistent frame callback stay at 600:
count those too before calling it a stutter. Runs of the same scene differ
by several frames a second, so compare in alternating series (sound on,
muted, three times each), not single runs.

Results on the iPad (release build, 120 Hz, budget 8.3 ms):

| Scene | fps | build p95 | raster p95 | frames > 16.7 ms |
| --- | --- | --- | --- | --- |
| Capture the flag 3 against 3, 10 min, 2 rounds, 24 carries, 16 respawns | 120 | 2.9 ms | 6.0 ms (worst window 9.6) | 0.1 % |
| Defense wave 30, sound on, before | 95 | 6.0 ms | 14.1 ms | 47 % |
| Defense wave 30, muted, before | 108 | 4.5 ms | 12.0 ms | 26 % |
| Defense wave 30, sound on, after | 95 | 5.7 ms | 14.4 ms | 47 % |
| Defense wave 30, muted, after | 105 | 4.7 ms | 12.3 ms | 31 % |

Sound in wave 30 (about 15 sounds a second admitted by the mixer): before,
the restart of a voice took a p95 of 4.4 s and up to 19 s, almost all of
it in `stop()`, which winds an AVPlayer back through iOS's media daemon;
the own shots were heard seconds late or not at all. After
(`VoiceTraffic`, three own voices, no position polling, `EngineThrottle`)
the p50 stays at 5 ms, platform calls fell from 40 to 30 a second, and a
sound that is not through within 120 ms is left out instead of coming
late. No errors, no players leaking (the count stays at the voices loaded
at start). What stays is the cost of AVPlayer itself, about 10 frames a
second in wave 30; only a mixing engine instead of one AVPlayer per voice
would remove it.

## Texts in two languages

Every visible text comes from `tr(de, en)` (`lib/src/l10n/l10n.dart`) at build
time. Picking another language in the account rebuilds the whole app below
`MaterialApp` (`LanguageRebuild` in `lib/src/ui/widgets/language_rebuild.dart`),
const widgets and the pages under the one on top included, so no widget needs
to listen to `L10n.lang` itself. A text kept in a field or a `late final`
outside `build` would still miss the change: read `tr` in `build`.

## Regenerating the typed database models

`lib/src/db/supabase_schema.g.dart` is generated by
`supabase_typegen` from `supabase/schema.json`, a snapshot of the postgres-meta
introspection document. After changing a migration, update the snapshot to
match and regenerate:

```sh
dart run supabase_typegen \
  --output lib/src/db/supabase_schema.g.dart \
  --import package:supabase_flutter/supabase_flutter.dart \
  < supabase/schema.json
```

Columns that were added to a table after it was created (the statistics,
`rating` and `xp` on `scores`, `style` on `players`) read with their default
in `supabase_schema.g.dart`, so the game survives a database that has not
been migrated yet. Put these fallbacks back after regenerating.

The types can also be generated straight from a database, without the
snapshot. A recent Supabase CLI (2.120 has it) supports Dart directly. Use
`--local` for the running local stack, or `--project-id your-project-ref` for a
hosted project after `supabase login`:

```sh
supabase gen types --lang dart --local > lib/src/db/supabase_schema.g.dart
```

The CLI runs the `supabase_typegen` dev dependency of the package it is called
from. On an older CLI, call the generator yourself:

```sh
dart run supabase_typegen --local --output lib/src/db/supabase_schema.g.dart
```

## Deploying

The game runs on GitHub Pages and talks to a hosted Supabase project, there
is no server of our own.

1. Create a Supabase project, then apply the migrations and allow anonymous
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
   is `true` (it is for the live game). Without it everybody plays as a
   guest without a way to sign in. For accounts the project
   needs:

   - Authentication, URL Configuration: the URL of the game as Site URL,
     and the same URL with `/**` as redirect URL. Mail links lead back to
     the start page of the game.
   - Sign In / Providers: anonymous sign-ins, e-mail and "Allow manual
     linking" switched on.
   - Authentication, Emails: an own SMTP server. Without it Supabase only
     mails the members of the project team, a few mails an hour. Then the
     German templates from `supabase/templates` for "Magic Link" and
     "Change Email Address", which also carry the code to type in.
   - Optional GitHub and Google logins: an OAuth app at the provider with
     the callback `https://your-project-ref.supabase.co/auth/v1/callback`,
     entered under Sign In / Providers. The game only shows the logins the
     project has switched on.

2. In the GitHub repository, set Pages to the "GitHub Actions" source and add
   the repository variables `SUPABASE_URL` and `SUPABASE_KEY` (the publishable
   key) under Settings, Secrets and variables, Actions, Variables, and
   `ACCOUNTS` set to `true` for accounts. Optionally `MAX_PILOTS` and
   `REALTIME_BUDGET` for another Supabase plan; without them the build keeps
   to what the Pro plan carries (4 and 400), and on the free plan they
   belong at 2 and 80, see
   [Rooms and room sizes](netcode.md#rooms-and-room-sizes).
3. Push to `main`. The `pages` workflow builds the landing page (Hugo,
   `site/`) into the root of the site and the game into `play/` below it,
   with the base path GitHub Pages reports, and publishes both. Without the variables the
   build falls back to the project configured in `lib/src/app/env.dart`.
   A `SUPABASE_URL` or `SUPABASE_KEY` that is no address or key (say,
   several `--dart-define`s glued into one quoted value) falls back the
   same way and logs why, and an iOS build in Xcode stops on it
   (`tool/check_dart_defines.sh` in the Flutter build phase).

GitHub only mails when a workflow fails, not when it recovers. The
`build-status` workflow fills that gap: when `ci` or `pages` fails on
`main`, it opens an issue labelled `build-failed` (one per workflow, later
failures add a comment), and the next green run closes it with a comment.
Watchers of the repository get a mail for both.

### CI minutes

In a private repository GitHub Actions bills every runner minute against
the plan: GitHub Pro includes 3,000 minutes and 1 GB of artifact storage a
month, a macOS minute counts about ten Linux minutes (US$0.062 against
US$0.006), and each job is rounded up to the whole minute. Before the
change a push to `main` cost about 165 of those minutes (ci with iOS, Mac,
watch and Android builds, then pages testing and building again), at some
85 pushes a month far beyond the plan. The workflows now keep a push near
ten Linux minutes:

| Workflow | Runs | Runner |
| --- | --- | --- |
| `pages` | every push to `main`: format, analyze, tests with coverage, web and landing page build, deploy, all in one job | Linux |
| `build-status` | after `pages` (and a manual `ci`) on `main` | Linux, single core (`ubuntu-slim`) |
| `ci` | pull requests: the checks only; by hand (`gh workflow run ci -f apple=true -f android=true -f watchos=false`): the native builds | Linux, macOS for Apple |

The rest of the savings: a newer push cancels the run still going
(`cancel-in-progress`), the Flutter SDK and pub packages come from the
Actions cache, every job has a `timeout-minutes` (the default would bill
six hours of a hung macOS job), and artifacts are kept for a day (the
site) or a week (store builds, which live on in TestFlight and Play).

CI only validates; nothing is released from it. The native builds are
checked locally, by the full `tool/verify.sh` before a push that touches
`pubspec.*`, `ios/`, `android/`, `tvos/`, the watch, assets or plugins, and
store builds are made and uploaded on the Mac (a TestFlight run on a macOS
runner would cost some 250 minutes per platform):

| Store | Script |
| --- | --- |
| TestFlight, iOS with the watch app | `tool/archive_ios.sh [--upload]` |
| TestFlight, Apple TV or Mac | `tool/archive_apple.sh tvos\|macos [--upload]` |
| App Store texts and screenshots | `bundle exec fastlane ios metadata` in `ios/` |
| Google Play, phone or Wear OS | `tool/release_android.sh phone\|wear [--upload <track>] [--metadata] [--completed]` |

Each builds with the release defines, checks the result (versions,
Supabase URL, signature) and uploads only with its flag. The keys stay on
the Mac and out of the repository: the Apple account signed in to Xcode,
`android/key.properties` with the upload key, the Play service account in
`android/play-service-account.json` and, for the store texts, an App Store
Connect API key. The repository holds no Actions secrets.

Keep the Actions budget of the account (Settings, Billing and licensing,
Budgets and alerts) at US$0 with "Stop usage when budget limit is
reached": then a month that runs out of minutes stops the workflows
instead of billing, and GitHub mails at 90 and 100 % of the included
minutes. The Pages site itself stays public and free when the repository
is private.

### Landing page

`site/` is a small Hugo site, the page in front of the game at
`/wargame/`. It is a "Feldseite" of Horizont, the design system of
regetskcob's projects (<https://github.com/regetskcob/horizont>, guide in
its `docs/web.md`): the head with the lockup and a quiet nav, a hero with
a Kennung, the headline in Literata, "Jetzt spielen" as the one primary
button, below it every device in one picture on the horizon line
(`site/assets/header/<lang>/devices.png` and `devices-narrow.png`, drawn
by `store/tool/landing.py` from the raw shots of `tool/store_shots.sh`),
then numbered sections
(`02 — Modi`, `03 — Geräte`, `04 — Beta`, `05 — Fair`) with facts in mono,
and the foot with "ein Projekt von regetskcob" and the legal links. The
page stays dark on Panzergefecht's own "Gelände" neutrals
(`data-product="panzergefecht" data-theme="dark"` on `<html>`); the signal
yellow belongs to the play button alone.

Horizont comes in as a Hugo module, pinned to a tag in `site/go.mod` and
`site/go.sum`. `site/hugo.toml` mounts its tokens, icon names, CSS,
partials (`layouts/_partials/horizont/`), shortcodes and fonts as its
`docs/web.md` says; the CSS is tokens, components, then `site/assets/css/site.css`
with only the page's own layout, every value a Horizont variable. The
layouts are built from the module's partials (`horizont/feld/*`,
`device.html`, `facts.html`, `kennung.html`, `badge.html`), never their HTML
again. To move to a newer Horizont, read its CHANGELOG, then:

```sh
cd site && hugo mod get github.com/regetskcob/horizont@vX.Y.Z
```

and check the page in both languages and at 375 px. Hugo fetches the
module with Go; the pages workflow uses the Go of the runner image, locally
`brew install go` is enough.

Texts and pictures are the App Store listing: name, subtitle, promotional
text and description come from `store/ios/metadata/<lang>/`, the shots
from `store/ios/screenshots/`, `mac/`, `tv/` and `watch/` (Hugo mounts in
`site/hugo.toml`). The store images carry a caption and a drawn device, so
`site/layouts/_partials/shot.html` cuts the bare screen out of them (the
rectangles in `site/data/screens.yaml` follow `store/tool/compose.py`;
measure again if its layout changes) and sets it in Horizont's device
frame, resized to WebP at build time. The description is read into its
parts, so its layout matters: an opening paragraph (the text of `02 —
Modi`), then sections whose first line is a heading in capitals (only the
first is used, the ways to play as `• Name: text`, of which the page shows
the first sentence as a fact), then loose paragraphs (the pledge and the
disclaimer make `05 — Fair`, the rest goes under the foot). Only the page's
own words live in `site/i18n/`, among them the devices section (browser,
iPhone and iPad, phone as controller, watch, TV, Mac), since the store
description is the iOS app's; `platformsNote` says what is out today and
is the place to update when a platform ships. `04 — Beta` lists the ways
into the apps in the order they have to be taken: the store pages once
`params.stores` in `site/hugo.toml` has them, then TestFlight, then for
Android the tester group before the closed test on Google Play. German sits
at the root, English under `en/`; a first visit follows the browser
language like the game does. The favicons are the web game's (`web/`).

The play button leads to `play/`, the game's start page with the four ways
to play. On the press the page lays the game's launch screen (ground and
tank) over itself, the same picture `web/index.html` starts with, so the
switch does not flash, and pointing at the button already prefetches the
game's scripts. Links that used to open the game at the old address (room
and pairing links of older apps, sign-in mails with `?code=`, home screen
shortcuts) are passed on to `play/` before the page draws, so they keep
working. The Impressum, privacy and licence pages stay at
`/wargame/impressum/`, `/wargame/datenschutz/` and `/wargame/lizenzen/`; the
licence page links the `NOTICES` file of the web build, which holds the
licences of every package and the engine, and adds Roboto in full. The game
shows the same under "Lizenzen" with Flutter's licence page, where
`LegalLinks` registers the Roboto licence as well.

`/wargame/support/` (and `en/support/`) is the support URL of the store
listings. Without a server of its own its form sends nothing: it writes
topic, device, call sign and message into a mail to `params.supportMail`
in `site/hugo.toml` and opens it in the visitor's mail app, so no form
service sees what people type. Real sending would need a Supabase Edge
Function with an SMTP account.

```sh
hugo server --source site          # http://localhost:1313/wargame/
```

The play button needs the game next to it; for the whole site as deployed:

```sh
flutter build web --base-href /wargame/play/
hugo --source site --baseURL http://localhost:8000/wargame/ -d /tmp/site/wargame
cp -R build/web /tmp/site/wargame/play
python3 -m http.server -d /tmp/site 8000
```

To build by hand:

```sh
flutter build web --base-href /your-repo/play/ \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_KEY=sb_publishable_...
```

## Fonts

The game uses the three voices of the design system
[Horizont](https://github.com/regetskcob/horizont): Mona Sans for everything
you operate, Mona Sans Display Expanded in capitals for headlines (the
game's character), Monaspace Argon with tabular figures for every value that
is counted or measured, and Literata for long reading text. They come with
the `horizont` package (`pubspec.yaml`, pinned to a tag), together with
their licences (`registerHorizontLicenses()`), so the app bundles no font of
its own. `GameType` in `lib/src/ui/theme.dart` names the styles the game
uses; widgets never set a `fontFamily` themselves.

Tests that measure text load the real fonts with `loadHorizontFonts()` from
`package:horizont/testing.dart`. The store tools (`store/tool/compose.py`,
`tv_icons.py`) find the same files through `store/tool/horizont_fonts.py`,
so run `flutter pub get` before them.

Since v0.6.3 Horizont cuts its fonts down to Latin with extensions,
punctuation and the few marks set as text (about 0.85 MB, 0.48 MB gzipped),
because the browser build loads every font before its first frame. A
character outside that range falls back to the system or Noto; the range
lives in Horizont's `tool/subset_fonts.py`, so a wider one goes there.

