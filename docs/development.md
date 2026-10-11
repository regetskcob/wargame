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

CI and `tool/verify.sh` run the tests with `--coverage` and
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

### Landing page

`site/` is a small Hugo site, the page in front of the game at
`/wargame/`. Its texts and pictures are the App Store listing: name,
subtitle, promotional text and description come from
`store/ios/metadata/<lang>/`, screenshots and the device artwork from
`store/ios/screenshots/` (Hugo mounts in `site/hugo.toml`, resized to WebP
at build time). The page stays short on purpose: device artwork opens it,
right under the name and the play button, because one room for browser,
phone, tablet, TV and watch is what sets the game apart. Unlike the App
Store header it shows every platform, out or coming, all alike on one
table (desk, TV with a phone as its controller, pocket and wrist); the line
under it (`platformsNote` in `site/i18n/`) says what is out today, so that
is the place to update when a platform ships. `store/tool/landing.py <raw
dir>` draws it from the raw shots of `tool/store_shots.sh` into
`site/assets/header/<lang>/`, one table for wide screens and two for
phones. The description is read into its
parts, so its layout matters: an opening paragraph (not shown), then
sections whose first line is a heading in capitals (only the first is
used, the ways to play as `• Name: text`, of which the page shows the first
sentence), then loose paragraphs (the first becomes the pledge under the
screenshots, the rest go into the footer). Only the page's own
words live in `site/i18n/`, among them the section on every screen the
game runs on (browser, iPhone and iPad, phone as controller, watch, TV),
since the store description is the iOS app's. German sits at the root, English under `en/`;
a first visit follows the browser language like the game does.

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

The four Roboto weights in `assets/fonts/` are cut down to Latin with its
extensions, punctuation, arrows and the few symbols the game shows (about
43 KB instead of 168 KB each), because the browser loads them before the
first frame. Letters outside that range come from the system fonts in the
apps and from Noto in the browser. To cut a fresh copy:

```sh
pyftsubset Roboto-Regular.ttf --unicodes="U+0020-007E,U+00A0-00FF,U+0100-017F,U+0218-021B,U+2010-2027,U+2030-203A,U+20AC,U+2122,U+2190-2193,U+221E,U+25CB,U+25CF" --layout-features='*' --no-hinting --output-file=assets/fonts/Roboto-Regular.ttf
```

`pyftsubset` comes with `pip install fonttools`. Check new texts for
characters outside that range before they ship.

