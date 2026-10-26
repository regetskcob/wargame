# Release test plan

What has to hold before a build goes to TestFlight, the App Store or Google
Play: function, load and reliability. The plan collects what the play tests
and QA sessions found and fixed in
[#12](https://github.com/regetskcob/wargame/issues/12) (play tests 1.2.1 to
1.3.0, the penetration and stress test),
[#21](https://github.com/regetskcob/wargame/issues/21) (TestFlight feedback
1.4.0) and [#23](https://github.com/regetskcob/wargame/issues/23) (QA
session 1.5.0), so none of it comes back unnoticed. The skill
`/release-test` runs it; `/release` calls it before any upload.

Every case has an id, the issue it comes from and how it is checked:

| Mark | Meaning |
| --- | --- |
| **auto** | a test in `test/` or a script, runs without a person |
| **sim** | Claude by hand in the browser (`/play-local`), the simulators or headless Chrome |
| **owner** | needs the owner: a real device, an e-mail address, a dashboard, an ear |

Severity decides the release: a failing **blocker** stops the upload, a
failing **major** needs the owner's word to ship anyway, a **minor** goes
into the release issue and the next version.

## 0. Scope

| Release | What runs |
| --- | --- |
| Minor or major (`x.Y.0`) | everything: sections 1 to 6 |
| Patch (`x.y.Z`) | sections 1, 2, 3.13 (older versions) and 5 in full; of 3 and 4 the cases whose area the diff since the last version bump touches, plus the smoke path S1–S6 |
| Store texts or screenshots only | 1, 3.12 (store and landing page) |

The diff since the last release is
`git diff $(git log -1 --format=%h --grep="Raise the version" HEAD~1)..HEAD --stat`
(the newest "Raise the version …" commit before the current one).

**Smoke path** (every release, every platform the build ships to): S1 the
app starts to the start page without an error in the log, S2 a solo round on
normal to the end screen, S3 NEW GAME starts the next round, S4 a waiting room
opens and a second player joins by code or link, S5 a defense round reaches
wave 2, S6 language switch DE ↔ EN changes every visible text.

## 1. Build identity

All **blocker**.

| Id | Check | How |
| --- | --- | --- |
| B1 | `pubspec.yaml` carries the new `x.y.z+build`, the build number is above every earlier upload to either store | auto: `grep version pubspec.yaml`, compare with the last "Raise the version" commit |
| B2 | `CHANGELOG.md` and `CHANGELOG.de.md` have the same version, sections and number of points | auto: diff the headings and bullet counts |
| B3 | `main` is clean and equal to `origin/main`, Pages and build-status green on that commit (the native builds are A1, locally) | auto: `git status`, `gh run list --branch main --limit 5` |
| B4 | Every migration in `supabase/migrations` is live | auto: `supabase migration list` shows each on both sides |
| B5 | The archive was built with the right defines: `tool/check_dart_defines.sh` passed in the Xcode build, `Env` points at the live project (build 4 shipped with all defines glued into `SUPABASE_URL`) | auto: `tool/archive_ios.sh` checks URL, versions, watch app and signature |
| B6 | The iOS archive contains the watch app (build 5 went out without one) | auto: `tool/archive_ios.sh`; after processing App Store Connect → TestFlight → "Apple Watch: yes" (owner) |
| B7 | No secret in the repo or the bundle (`key.properties`, service keys) | auto: `git grep -nE "service_role|sb_secret|BEGIN (RSA|EC) PRIVATE"` finds nothing |

## 2. Automated gate

All **blocker** unless marked. Runs on the release commit.

| Id | Check | Command |
| --- | --- | --- |
| A1 | Format, analyze, all tests without the `supabase` tag, coverage ≥ 75 %, builds for web, landing page, iOS, macOS, Android, Wear OS | `tool/verify.sh` |
| A2 | Every mode on every bot level plays through without a throw; two real games in one room over `LoopbackNet`; every overlay on desktop and phone, DE and EN, without overflow | part of A1: `smoke_test`, `two_player_smoke_test`, `overlays_smoke_test` |
| A3 | Wire format and RPC contract unchanged for older clients | part of A1: `wire_format_test`, `rpc_contract_test` |
| A4 | Realtime budget: rooms, phones, presence bursts stay within `GameConfig.roomLoad` / `padLoad` | part of A1: `message_budget_test`, `pad_budget_test`, `presence_throttle_test`, `room_capacity_test`, `pad_screen_test`, `rooms_busy_test` |
| A5 | Hostile peers: ~14,000 bent messages and input chaos in every mode throw nothing; forged close, round start, blasts, floods, spoofed flags are refused (#12 A1–A14) | part of A1: `hostile_fuzz_test`, `hostile_room_test`, `hostile_payload_test`, `plausibility_test` |
| A6 | Against a local stack: Broadcast, Presence, `scores`, phone controller | `supabase start`, then `flutter test --tags supabase` (**major**; skip only if Docker is missing and say so) |
| A7 | Balance in the bands below (**major**), in a starter and again in the Wolf (`--dart-define=VEHICLE=wolf`): CPU tanks mirror the player's vehicle, so a rank must not change the odds much | `flutter test test/game/balance_sim_test.dart --run-skipped --dart-define=ROUNDS=100` |
| A8 | Defense builds pay for themselves (**major**) | `flutter test test/game/defense/trench_balance_sim_test.dart --run-skipped --dart-define=ROUNDS=8`, again with `WAVE=5` |
| A9 | Flaky tests: the suite passes three runs in a row (#23: a squad test failed once in the full suite) | `for i in 1 2 3; do flutter test --exclude-tags supabase || break; done` (**major**) |

**Balance bands for A7** (wins out of 100 daytime rounds; the last measured
numbers are in [Balance](gameplay.md#balance)). Outside a band is not a
blocker by itself, but a change of more than 15 points against the last
release needs a sentence in the release issue and the owner's nod.

| Level | Idle | Aim assist only | Like a normal CPU tank |
| --- | --- | --- | --- |
| easy | ≤ 12 % | ≥ 65 % | 35–65 % |
| normal | ≤ 10 % | 35–75 % | 18–50 % |
| hard | ≤ 10 % | 15–45 % | 10–35 % |

Also: hard stays below normal for the player at normal CPU level, and doing
nothing never wins more often than one round in ten (#12 "doing nothing
wins").

**A8 expectations:** at wave 3 the trench on the road earns at least 80 % of
its price and keeps hits on the base at most half of "nothing"; the cannon
stops at least four in five tanks; no build lets a soldier through that it
stopped in the last release.

## 3. Function

Mostly **sim**; real devices in section 6. Severity in the last column
(B blocker, M major, m minor).

### 3.1 Start page and first launch

| Id | Case | From | How | Sev |
| --- | --- | --- | --- | --- |
| F1.1 | The start page shows without waiting for the server: guest sign-in, profile and progress load behind it | #12 next 1 | sim: headless Chrome, network throttled to 3G, menu visible before the leaderboard | M |
| F1.2 | A guest keeps call sign and vehicle style over two restarts, also when progress times out | #12 next 2 | sim: iPhone simulator, restart twice, compare the call sign with `players` | B |
| F1.3 | The start page does not move when the leaderboard arrives (five rows held) or reloads every 30 s | #12, #23 M1 | auto: `leaderboard_test`; sim: click a mode card the moment the list arrives | M |
| F1.4 | Leave the start page in a background tab for 10+ minutes, come back, pick a mode: the waiting room stays open | #23 H1 | auto: `idle_room_test`; sim once in the browser | B |
| F1.5 | A device that never finished a round starts on easy; the first round of a session starts by day under a clear sky | #12 high | auto: `gentle_start_test`, `weather_test` | M |
| F1.6 | PLAY NOW starts solo with the last tank and difficulty in one tap; LAST PLAYED on desktop and tablet only, not on phones | #12 next 3 | auto: `quick_flow_test`; sim on phone and desktop size | M |
| F1.7 | The difficulty survives a restart and LAST PLAYED names it | #12 hard | auto: `gentle_start_test` (`chooseLevel`) | M |
| F1.8 | Guests and 0-0-0 rows are not in the leaderboard, ranking is by points | #12 low, 1.3.0 | auto: `leaderboard_test` | M |
| F1.9 | Web: loading bar, "Das Spiel lädt …" and a tip until Flutter draws; the hint leaves the DOM afterwards | #12 low | auto: `loading_view_test`; sim | m |
| F1.10 | "VIER WEGE ZU SPIELEN" above four modes | #23 W5 | auto: `glossary_test` | m |

### 3.2 Waiting room and settings

| Id | Case | From | How | Sev |
| --- | --- | --- | --- | --- |
| F2.1 | The settings line (difficulty · terrain · mode) opens the settings for the host | #12 high | sim | M |
| F2.2 | A guest sees the host's line dimmed, not tappable, with the host's mode | #23 M5, #12 1.3.0 | auto: `guest_mode_test`; sim with two browser profiles | M |
| F2.3 | Vehicle cards fill the box and sit centred on a 375–390 px phone | #23 M2 | sim at 390 px and on the iPhone | m |
| F2.4 | Camouflage in rows of even length (4 + 4 or one row) on phone and iPad | #23 M3 | sim | m |
| F2.5 | Settings end in the full-width pair Change mode · Done | #23 L2 | sim | m |
| F2.6 | The waiting room does not jump when the first replay appears | #12 evening | sim: play a round, come back | m |
| F2.7 | Phones offer neither duel nor split screen when they see a controller | #12 1.3.0 | auto: `controller_section_test` (`splitScreenFits`) | M |

### 3.3 Solo round

| Id | Case | From | How | Sev |
| --- | --- | --- | --- | --- |
| F3.1 | Gentle start: CPU tanks leave people alone for the first seconds (easy 10, normal 8, hard 5) unless hit | #12 high | auto: `gentle_start_test` | B |
| F3.2 | Countdown 2 s alone, 3 s with other people, the digit sits above the own tank | #12 | auto: `quick_flow_test`; sim | m |
| F3.3 | The aim assist exists on every level, reads "fires by itself", sits as a pill above the aim zone, and actually fires, also after a HUD rebuild on a tablet | #12 evening (high), 5bb1e56 | auto: `touch_controls_test`, `hud_overlay_test`; sim: idle iPad round deals damage | B |
| F3.4 | CPU tanks fire at a person only within that person's sight (night 42 m, fog 52 m) | #12 hard | auto: `bot_level_test` (`BotBrain.reach`) | M |
| F3.5 | CPU tanks drive the vehicles of the people in the round (alone the player's own, in red against blue pair by pair); every vehicle stays winnable on every level | #12 evening, #24 | auto: `cpu_fairness_test`; balance sim per vehicle (`VEHICLE=`) | M |
| F3.6 | Off-screen arrows keep 34 px apart, slide past gauges, mini map and panels, show distance in metres; the zone is in metres | #12 | auto: `enemy_indicators_test` | m |
| F3.7 | Kill feed: a tank lost in the zone "ist ausgeschieden / is out", not "dropped out" | #23 M7 | auto: `kill_feed_view_test` | m |
| F3.8 | End screen: NEW GAME starts a new round with the same tank and settings; alone it waits, with others it counts 15 s on its button | #12 high | auto: `quick_flow_test`; sim | B |
| F3.9 | End screen buttons share one width (≤ 320) on every size | #23 M4 | auto: `overlays_smoke_test` | m |
| F3.10 | Replay: END REPLAY sits in the top bar next to NEXT TANK, Esc leaves it, the end is in the bar | #21 4 | auto: `replay_bar_test` | m |
| F3.11 | Leave asks first ("Leave the round?") and the round goes on behind the dialog | #12 | sim | M |
| F3.12 | Own call sign readable on snow and sand (halo), leave button visible (dark disc) | #12 evening | sim: winter map screenshot | m |
| F3.13 | Inventory shows filled slots only; items 1–6 work | #12 | auto: `smoke_test`, `special_weapons_test` | m |

### 3.4 Multiplayer and rooms

| Id | Case | From | How | Sev |
| --- | --- | --- | --- | --- |
| F4.1 | Host + guest in two browser profiles against the hosted project play to the end screen | #23 | sim | B |
| F4.2 | Join by code, by link and from the room list; a public room shows in the list within ~5 s | #12 1.3.0 | sim | B |
| F4.3 | Two owners of one room (second tab) leave the host role to one | #12 1.3.0 | auto: `room_host_test` | M |
| F4.4 | A fifth pilot is turned away with "Der Raum ist voll: höchstens 4 Piloten.", the four play on | #12 D | auto: `room_capacity_test`; sim with five profiles | M |
| F4.5 | The host leaving closes the room for everyone ("you left the round"); a guest leaving lets the others play on | #12 | auto: `leave_round_test` (solo, host and guest leaving a battle of two) | M |
| F4.6 | Teams: frames, tags and tanks in the team colour, also on a split screen | #12 summary | auto: `round_state_teams_test`, `split_view_test` | m |
| F4.7 | A room with a phone fills no CPU tanks; without a server the game starts offline (`ServerStatus`), a 402 shows the busy message | CLAUDE.md, #12 | auto: `server_status_test`, `rooms_busy_test` | M |
| F4.8 | Red against blue on AUTO: a new player and a veteran play on one side (with CPU fill) or one veteran with one new player per side (four people, no fill); a picked side stays picked; the CPU tanks across drive the vehicles without a counterpart | #24 | auto: `cpu_fairness_test` | M |

### 3.5 Defense

| Id | Case | From | How | Sev |
| --- | --- | --- | --- | --- |
| F5.1 | A round reaches wave 3 (aircraft) with guns built; WAVE NOW / key N calls the next wave early | #12 next 3 | sim; auto: `defense_test` | B |
| F5.2 | The build menu leaves no mark on the last gun; too expensive guns are disabled, nothing else | #21 1 | auto: `hud_overlay_test`; sim with coins below 120 | M |
| F5.3 | A line says what earns coins, "+20" rises from own kills, a notice says when the coins reach for a gun or an upgrade | #12 medium, #21 2 | sim | m |
| F5.4 | The trench notice names halved damage and the anti-tank rocket from wave 4 | #21 2, #23 W6 | auto: `defense_test`; sim: dig a trench | m |
| F5.5 | The last helicopter of a wave comes in to the base; tank shells hurt it | #21 3 | auto: `last_helicopter_test` | M |
| F5.6 | Desktop 1280×800: wave banner above the middle, panel ≤ 540 px with tabs GUNS / UPGRADES, the mini map not over the base, inventory clears the panel | #12 medium, next 6, #12 C | sim at 1280×800 | m |
| F5.9 | The open list of the defense panel (GUNS / UPGRADES) is marked by its tint and a line along its foot, never by a frame in the accent, which on the television read as the focus ring | sim test 2026-10-19 | sim: Apple TV round menu, iPhone | m |
| F5.7 | A gun the host destroys disappears on its builder's screen too | #12 A7 | auto: `hostile_room_test` / `two_player_smoke_test` | M |
| F5.8 | Extension after wave 8, defense duel on lanes | gameplay | auto: `extension_test`, `defense_duel_test` | M |

### 3.6 Capture the flag

| Id | Case | From | How | Sev |
| --- | --- | --- | --- | --- |
| F6.1 | Red against blue across two devices (iPhone sim + browser), CPU tanks fill to 3 against 3, respawn, the host carries the flags | #12 1.3.0 | sim; auto: `flag_round_test`, `flag_match_test`, `flag_duo_test` | B |
| F6.2 | Flag banners in one form of address ("Hol eure Fahne zurück!") | #23 W5 | auto: `glossary_test` | m |

### 3.7 Phone controller and split screen

| Id | Case | From | How | Sev |
| --- | --- | --- | --- | --- |
| F7.1 | The app on a phone pairs by QR or link and drives a round of the screen (browser, iPad, Apple TV); the code scanned with the iPhone's own camera opens the app, not Safari | #23, 1.6.0 on the Apple TV | sim: iPhone simulator as pad of the browser game; `curl -s https://panzergefecht.de/.well-known/apple-app-site-association` lists `room` and `pad`; owner: system camera on a real iPhone (simulators skip universal links) | B |
| F7.2 | The phone's gauges match the HUD (crate for ammo, `100 %`) | #23 M6 | auto: `controller_view_test` | m |
| F7.3 | A touch brings the sticks back over a connected controller; using the controller hides them again | #12 next 5 | auto: `touch_controls_test`; owner with a real controller | M |
| F7.4 | Two phones on an iPad: split screen, player two named after the phone, same plates, own survival time on each end screen, team colours | #12 1.3.0, summary | sim: iPad sim + two phones; auto: `split_view_test` | M |
| F7.5 | A second phone paired during the results joins at the next round, its half not empty | #12 C | auto: `pad_screen_test` | m |
| F7.6 | A phone that drops for 5 s comes back and shows the round's end; one leaving mid-round leaves the round running | #12 C | sim | M |
| F7.7 | At most four lanes; strangers' `pad`/`act` change nothing | #12 A14 | auto: `pad_link_test`, `hostile_room_test` | M |

### 3.8 Account, ranks and progress

| Id | Case | From | How | Sev |
| --- | --- | --- | --- | --- |
| F8.1 | Register, confirm by e-mail, sign in, sign out, sign in on a second device | #12 (deferred) | owner: a real address | B for releases that touch `lib/src/db/` or auth, else M |
| F8.2 | A signed-in round raises rating and XP once; the rank bar counts each rank from zero; unlocks move with the rank | #21 6 | auto: `progress_test`, `score_points_test`; owner after F8.1 | M |
| F8.3 | The account is a page of its own, delete account at the very bottom, delete leaves nothing behind | #21 5 | auto: `account_page_test` (phone and tablet); `delete_account` in R2 | M |
| F8.4 | A call sign change shows live on the other device; control characters and RTL overrides are cleaned | #12 1.3.0, A13 | auto: `call_sign_test` | m |

### 3.9 Words in two languages

| Id | Case | From | How | Sev |
| --- | --- | --- | --- | --- |
| F9.1 | Switching the language rebuilds everything, mode cards and footer links included | #21 | auto: `l10n_test`; sim | M |
| F9.2 | One word per thing everywhere (game, tutorial, watch, iMessage, Live Activity, store, landing page) | #23 W1–W5, W7 | auto: `glossary_test` reads every `tr()` in Dart and Swift, the store texts and the landing page | m |

Glossary (DE / EN) to grep for strays: GESCHÜTZE / GUNS (never Türme,
turret), AUFRÜSTUNG / UPGRADES, LEICHT · MITTEL · SCHWER / EASY · NORMAL ·
HARD (never "Normal" in German), Schwierigkeit / difficulty (Stufe only for
the pilot's level and gun levels), Stützpunkt / base (never Basis, Lager),
Münzen / coins (never Geld, Mittel, funds, money; Mittel is only the difficulty), NEUES SPIEL / NEW GAME (never Nochmal,
Revanche), Gastgeber / host, "Einsatzbereit in … s" / "Ready in … s",
Beobachte / watching, Raumcode / room code, Gefechtsplatz / Battlefield,
Warteraum · Bereitstellung, WIEDERHOLUNG / REPLAY, ABSCHUSS / KILL, e-mail, Gewonnen (never Sieg).

### 3.10 Tutorial

| Id | Case | From | How | Sev |
| --- | --- | --- | --- | --- |
| F10.1 | Practice cards set a task (drive into the ring, 3 hits), show progress and move on | #12 low | auto: `practice_test`, `tutorial_test` | m |
| F10.2 | The tutorial says what the game says (MITTEL, DREI SCHWIERIGKEITEN, aim assist on every level, also on TV) | #23 W2, W5 | auto: `glossary_test`; sim: read the tutorial cards | m |

### 3.11 Platforms

Per platform the smoke path S1–S6 where the platform has it, plus:

| Id | Platform | Case | How | Sev |
| --- | --- | --- | --- | --- |
| F11.1 | iPhone | upright layout zooms closer, sticks, aim assist pill, haptics | sim iPhone 18 Pro, owner on BoPhone | B |
| F11.2 | iPad | menus scaled, account page, split screen, Vision Pro compatibility (look + pinch) | sim iPad Pro 13", owner on BoPad | M |
| F11.3 | Web | release build, semantics tree after "Enable accessibility" (13 labelled buttons), mute button | sim | B |
| F11.4 | macOS | starts, full screen, sound button, controller | sim; owner for a look (locked screen gives black screenshots) | M |
| F11.5 | Apple TV | focus frame, controller box, remote and controller, second player and split screen, base duel; swiping over every text field (room code, call sign, e-mail, code) moves the focus one step and opens no keyboard, a click opens it; in a round Menu opens the round menu (in defense every gun and upgrade reachable, play/pause presses, leaving asks), the last helicopter of a wave can be shot with the remote | sim Apple TV 4K; auto: `tv_input_test`, `select_to_type_test`; owner with the Siri Remote on a real Apple TV (the simulator gets no remote presses, and the stuck key repeat of 1.6.0 lives in the engine) | M |
| F11.6 | Android TV / Fire TV | remote as pad | auto: `android_tv_test` | m |
| F11.7 | Apple Watch | every mode alone against CPU tanks, no room channel, NEUES SPIEL, rounds count for the iPhone's account via WatchConnectivity, rounds after an expired token wait for the next one | auto: `watch_*`, `offline_modes_test`, `account_link_test`; sim (grant "Let Claude use it" first); owner on a real watch | M |
| F11.8 | Wear OS | crown, round HUD, vibration, "Gast, ohne Wertung" | auto: `wear_crown_test`, `wear_haptics_test` | m |
| F11.9 | iMessage | the bubble invites into a room and opens the app with mode and host; titles Mehrspieler / Fahnenraub / Verteidigung / Duell; the result comes back over the app group | owner: two real devices in one chat | M |
| F11.10 | Live Activity and online widget | round and defense state, "Stützpunkt", heartbeat | sim | m |

### 3.12 Store and landing page

| Id | Case | From | How | Sev |
| --- | --- | --- | --- | --- |
| F12.1 | Store texts (iOS, Play) and the landing page name things as the game does (glossary above); the English and German promo say the same | #23 W7 | sim: read `store/`, `site/` | M |
| F12.2 | Screenshots show the current build (`tool/store_shots.sh` + contact sheet), no real vehicle names, no "Bundeswehr" | memory | sim | M |
| F12.3 | Release notes match the changelog of this version | release skill | sim | M |

### 3.13 Older versions against this release

The web goes live with the push, the stores follow days later and not every
player updates, so for weeks the new release meets the last one (and older)
in the same rooms and on the same database. Runs on **every** release, patch
included.

**The old build:** the last release is the commit of the newest "Raise the
version" before the current one (as in section 0). Check it out with
`git worktree add ../wargame-prev <commit>` and build it there against the
hosted project: `flutter build web --release` with the same defines, served
on a second port, and `flutter run` on a second simulator. The owner keeps the
current store build on a real device and does not update it before the run
(TestFlight can also install the previous build).

| Id | Case | How | Sev |
| --- | --- | --- | --- |
| F13.1 | Old host, new guest **and** new host, old guest: join by code and link, the room list shows the other's room, a battle with CPU fill plays to the end screen on both, NEW GAME starts the next round on both | sim: two browser profiles, one on the old web build, one on the new | B |
| F13.2 | The same in defense (waves, guns, base, extension) and capture the flag (flags, respawn): neither side throws, the guest sees the host's waves, guns and flags | sim: old ↔ new web build | B |
| F13.3 | Content level: a room with an old client never rolls a newer map, defense layout or enemy (`roomContent`, `DefenseMap.freshRoom`); a new pilot's vehicle shows on the old client as the Keiler | auto: `new_maps_test`; sim: old guest in a new host's room, compare the map on both screens | B |
| F13.4 | Presence and payloads: fields this release added are optional, an old client's presence without them works in a new room (no settings line, no `content` means level 0) | auto: `wire_format_test` (no event renamed, no field dropped); sim: F13.1 | B |
| F13.5 | Phone controller across versions: the old app as pad of the new screen and the new app as pad of the old screen pair and drive a round; new `act` kinds are dropped by the old side without a throw | sim: old and new build on two iPhone simulators against the web | M |
| F13.6 | Database: the old client's `record_round`, `claim_load`, heartbeat and leaderboard calls succeed against every migration of this release (no renamed parameter, no new required one) | auto: `rpc_contract_test` (functions and parameters the client calls exist); owner: a round on the old store build signed in raises XP once | B |
| F13.7 | Watch and iMessage: the old watch app with the new iPhone app (token handover, rounds count); an iMessage bubble sent from the old version opens the new app in the right room and mode | owner: real watch and two devices in one chat | M |
| F13.8 | Two versions back (the store build before the last one) can still start, play solo and see the leaderboard | owner: oldest TestFlight build still installable, or sim from a worktree | m |

Where the two versions behave differently in one room (the old side drops a
new message kind, or plays without a new feature), the release notes say so.
If a case fails because the change cannot be made compatible, ship web and
both stores together and say so in the release issue (as with migrations
0015/0016 in `docs/netcode.md`).

## 4. Load and performance

| Id | Case | Target | How | Sev |
| --- | --- | --- | --- | --- |
| L1 | Messages per room on the wire, 4 pilots + CPU tanks, and per phone | within `GameConfig.roomLoad` / `padLoad`; alone in a room nothing is sent | auto: A4 | B |
| L2 | Web load time to a readable start page, live page, headless Chrome, CPU ×4 | first visit fast ≤ 3.5 s, 4G ≤ 6 s, 3G ≤ 20 s; again ≤ 2.5 s (#23: 3.2 / 5.1 / 17.3, again 2.1–2.5) | sim, after the deploy of the release commit | M |
| L3 | Long defense session headless: forced waves 20, 30, 40, 50, then 30 twice more | live entities capped, no fallen soldiers left in squads, splats ≤ 60, `update` and `render` time flat over the session, replay buffer bounded | auto (by hand): `flutter test test/game/defense/long_session_bench_test.dart --run-skipped --dart-define=SECONDS=60` (tag `benchmark`), prints a table for the release issue | M |
| L4 | Frame time on the BoPad (A12X, profile build), forced defense wave 30 with up to 14 guns | raster p90 ≤ 15 ms at wave 30, solo raster p90 ≤ 9 ms, few missed frames; capture the flag measured alongside | owner: BoPad unlocked, auto-lock off; then Claude runs `flutter drive --profile -d <device> --driver=test_driver/perf_driver.dart --target=integration_test/frame_timing_test.dart` (scenes solo, defense wave 30, flag) | M |
| L5 | Four game instances on one Mac in one room | 45–60 fps in the round, heap 30–85 MB without growth | sim | m |
| L6 | Input storm: start hammered five times, 2,000 random keys in 10 s, 150 taps in 5 s on the phone controller plus erratic drags, item keys held | one round starts, no stuck key, no error | sim | M |
| L7 | Sound and haptics late in a defense wave (wave 12, six comrades) | no stutter, own shot always heard, field blasts at most twice a second as taps | auto: `sound_mixer_test`, `haptics_test`; owner by ear on a phone | M |
| L8 | Flood against the hosted Realtime | **never** against the live project; only on a separate project or branch on the owner's word | owner | – |

## 5. Reliability and robustness

| Id | Case | Target | How | Sev |
| --- | --- | --- | --- | --- |
| R1 | Hostile peers (#12 A1–A14) | refused or capped, nothing throws | auto: A5 | B |
| R2 | Database: `claim_load` caps (room 400, phone 160, `p_force` ignored), `record_round` limits (live opponents only, 300 a day, kills tied to time), server time for badges, no direct writes, empty `search_path` on every security definer function, `delete_account` leaves nothing | all hold | auto: `rpc_contract_test`; sim: PGlite with all migrations and an auth stub (`/db-migration`), only when `supabase/` changed since the last release | B |
| R3 | Defense of four, one client offline for 4 s | plays on in the same round with tank and guns (6 s grace) | sim: headless Chrome, network off | M |
| R4 | Socket drops and returns | room rejoins with backoff, the log names the reason | auto: `retry_backoff_test`; sim | M |
| R5 | Without a server (no network on start, 402) | the game starts, solo works, rooms say why they are missing | auto: `server_status_test`; sim with the network off | B |
| R6 | Lifecycle: hidden tab, app in the background, rotation, window resize, iPad sleep and wake, leaving and rejoining in the countdown | no stuck round, no closed room after waking (F1.4), no error | sim; owner for sleep on a real iPad | M |
| R7 | Late and doubled events: a death from the last round after a rematch, replayed messages | ignored | auto: `hostile_room_test` | M |
| R8 | Fresh install: delete the app, start the archived build on a real device | the leaderboard loads, the device log has no `Server check failed` | owner (from `/release`) | B |
| R9 | No unhandled error over the whole session: browser console, `preview_logs`, `idevicesyslog -p Panzergefecht`, the simulators' logs (e.g. `AudioPlayer has been disposed`) | zero | sim, collected over sections 3 and 4 | M |
| R10 | Plugins without a watch package (`app_links`, `share_plus`, `mobile_scanner`) are not called on the watch | no `MissingPluginException` | sim: watch log | M |
| R11 | The Apple Watch never listens on the gamepad channel (it reports iOS but has no gamepad plugin) | no `MissingPluginException` on `wargame/gamepad` | auto: `pads_supported_test` | M |
| R12 | Television: a button pressed away under the focus does not make the focus frame throw every frame | no "Cannot get renderObject of inactive element" in the TV log | sim: Apple TV, walk menus and press buttons that change the page | M |

## 6. Accepted open risks

Known and decided; each release confirms nothing made them worse and asks
the owner whether they still stand. Room identity, the XP ticket for
rounds against CPU tanks, `claim_load` of other rooms and the defense host
takeover were closed in f7c83b7 (#12) and are no longer here.

- **Builds before the room keys** still play, unsigned and only in their
  own name; their rounds count without a ticket and earn nothing from CPU
  tanks. Goes away as those builds die out; 3.13 keeps them playable.
- **A flood closes every channel of the project.** Above the message limit
  Realtime shuts all rooms for about 10 s (`docs/netcode.md` "Flood
  behaviour"); the game rejoins with backoff and keeps rounds together, but
  only Supabase can stop the shutdown itself.
- **Sound at defense wave 30** costs about 10 fps on the BoPad (AVPlayer);
  a mixing audio engine would win them back.
- **Not covered by Claude:** human fingers on a real touch screen (five
  pointers were only tested in code), two real phones as controllers, a
  real Bluetooth controller, account flows with a real address, sound by
  ear, the watch on a real wrist, a look at the Mac app. These are the
  owner's rows in sections 3–5 (#12, #23).

## 7. Result and sign-off

The run ends in a GitHub issue "Release test x.y.z (build)" with:

1. Commit, version, scope (full or patch, with the reason) and where it ran
   (as in #23: platform, build, what was played).
2. One table per section with id, result (pass / fail / skipped / owner)
   and a note; every fail with severity and, if fixed in the run, the
   commit.
3. The balance and load numbers next to the last release's.
4. "Needs you": the owner rows, bundled, each with how to do it.
5. The verdict: **GO** (no blocker open, majors decided), **GO with
   owner rows** (only owner rows left) or **NO GO** (a blocker failed).

`/release` uploads only after **GO**, or after **GO with owner rows** once
the owner has done them or waived them in chat.
