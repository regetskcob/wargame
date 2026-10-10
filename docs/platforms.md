# Platforms

The web game is the main target. The same code runs as apps on iOS, Android, the Mac, the Apple Watch and the Apple TV, and the iPad app on the Apple Vision Pro.

## Mobile apps (iOS and Android)

The project carries `ios/` and `android/` next to `macos/` and `web/`. The
apps are called Panzergefecht, with the bundle and app id
`de.regetskcob.wargame` on iOS and Android (kept from an earlier name, store
ids cannot change). The iOS product is `Panzergefecht.app`, the Xcode target
and scheme stay `Runner`, which `flutter build ios` expects. On phones
and tablets the game plays upright or sideways, hides the system bars, and
shows the on-screen touch controls. The camera shows the same stretch of the
world along the shorter side, so upright shows more of the field above and
below; in a defense round the field's height fills an upright screen. The
apps have no mute button: the sounds follow the silent switch and the volume
keys, and mix with music from other apps. Phones vibrate with the game
(`lib/src/haptics.dart`, Flutter's `HapticFeedback`: the Taptic Engine on the
iPhone, the vibration motor on Android): a light tap for a blast close by, a
hard knock for a heavy hit, the own tank destroyed and the end of a round, a
click per second of the countdown and a firm tap at the start. A switch in the
account sheet turns it off, Android also follows the system setting for touch
vibration. iPads and most Android tablets have no motor and stay still. Android has the `INTERNET`
permission in the main manifest, so release builds can reach Supabase.

The start page does not wait for the server: a first visit signs in as a
guest in the background (`ServerStatus.ensureSession`, shared with the
first heartbeat), the call sign and style kept on the device
(`rememberPilot`) show at once, and the server's profile and progress
follow side by side when they arrive. The sounds load after the first
frame of the start page. The launch screen shows the tank of the app icon on a calm version of its
ground, and `LoadingView` (`lib/src/ui/loading_view.dart`) keeps exactly
that with a spinner below, from the first Flutter frame until the game has
loaded; the web page shows the same from `web/index.html` before Flutter
starts, from the built assets under `assets/assets/images/`, so the loading
view finds them in the browser cache. Android draws only the ground colour behind the tank
(`@color/launch_ground`); since Android 12 the system splash shows the tank
as its icon (`values-v31/styles.xml`), before that `launch_background.xml`
does. `python3 store/tool/launch_screen.py` draws the images for all of
them (iOS image sets, Android drawables, `assets/images/`).

You need a full Xcode (iOS) and a JDK with the Android SDK (Android), see
`flutter doctor`. Then:

```sh
flutter run -d <device-id>   # a simulator, an emulator, or a plugged in phone
flutter build apk --release        # Android APK
flutter build appbundle --release  # Android App Bundle for Google Play
flutter build ios --release        # iOS, set your signing team in Xcode first
```

Pass `--dart-define=SUPABASE_URL=...` and `--dart-define=SUPABASE_KEY=...` as
for the web build. CI builds the iOS app without signing
(`flutter build ios --release --no-codesign`) and the Android App Bundle with
the debug key on every push. To sign, add your Apple ID in
Xcode (Settings > Accounts), open `ios/Runner.xcworkspace` and pick your team
under Signing & Capabilities. The app declares that it uses no non-exempt
encryption, so App Store Connect skips the export compliance question. On
iOS and Android sign-in mails are confirmed with the code from the mail, the
link in it opens the web game. To sign the Android release, copy
`android/key.properties.example` to `android/key.properties` and point it at
your upload key; without it Gradle signs with the debug key, which Google Play
rejects. Store texts, icons and screenshots for both stores live in
`store/ios` and `store/android`, each with a README of what goes where. The
`play` workflow (run by hand) builds the signed bundle and uploads it to a
Google Play track with fastlane, see `store/android/README.md` for the
secrets. To play
a local stack from an Android emulator use `http://10.0.2.2:54621`, from a real
phone the LAN address of your Mac.

## iMessage

`ios/MessagesExtension` is a Messages extension in plain Swift and SwiftUI
that ships inside the iOS app. It only invites, the game never runs in
Messages: Flutter recommends at least 100 MB for an extension's UI, Apple
names no limit for Messages extensions and ends one that takes too much
without warning, and Messages starts an instance of the extension for every
interactive bubble.

1. In a chat the extension offers what fits who is in it, read from
   `remoteParticipantIdentifiers` (Messages hides who they are). In a chat
   for two: tower defense together, the base duel and Last Tank Standing. In
   a group: Last Tank Standing and capture the flag, with a note when the
   chat has more people than `MAX_PILOTS` (later ones watch).
2. A choice puts a bubble with a fresh room code into the input field. The
   link in it is the usual room link with the mode added,
   `https://www.regetskcob.de/wargame/play/?room=CODE&mode=defense`, so it
   also opens the browser game on a phone without the app.
3. Once the player sends it, the extension opens the app at
   `panzergefecht://play?room=CODE&mode=defense&host=1`. An extension may
   only open its own app, and only while that sits on the home screen.
   `listenForRoomLinks` (`room_stub.dart`) then opens the room as its host
   (`hostRoom`) and `chooseInvitedMode` skips the start page in that mode:
   `multi`, `flag`, `defense` or `duel`.
4. Tapping the bubble opens the extension with the invitation and a button
   into the room. Whoever sent it goes back in as the host: the extension
   keeps the rooms it sent in its own `UserDefaults`, because the simulator
   hands out a different participant id for the sender of a message than
   for the local player. Everybody else joins as a guest, and the lobby
   gives each their own tank as with any other room link.

5. When a round ends, `LiveActivityPlugin.swift` (which hears of every
   round anyway) leaves its result in the defaults of the app group
   `group.de.regetskcob.wargame`, as `ChatResult` (`ios/Shared`). The app
   writes every round, it knows nothing of chats. The extension keeps the
   session of every bubble it sent or followed, archived with the chat it
   came from, and offers the newest result of such a room the next time it
   opens in that chat: "Ergebnis in den Chat" puts a bubble with the same
   picture and the result line in the same session into the input field,
   so once it is sent the chat shows it in place of the invitation, which
   collapses to a line. The link still leads into the room for another
   round. Results older than a day are not offered.

Guests learn the mode when the round starts, as with every room, so their
waiting room shows the default text until then. While the host's app sits
in the background behind Messages, a guest who comes in first stands in as
host and hands back once the owner returns.

To try it, build for the simulator, install the app, open Messages, a chat
with one of its fake numbers and the app list behind "+". After installing
a new build, quit Messages once, or it keeps looking for the old extension.
`python3 store/tool/imessage.py` draws the icons in
`iMessage App Icon.stickersiconset` from the layers of the app icon and the
two pictures of the bubble: tanks of three colours on the battle ground for
Last Tank Standing and capture the flag, the red defence holding its base
on a sandy road against blue tanks for the defense and the duel. Both app
and extension carry the app group in their entitlements; signing in the
`testflight` workflow registers it with `-allowProvisioningUpdates`.

## Mac

`macos/` builds the game as a Mac app, `Panzergefecht.app`, with the same
bundle id `de.regetskcob.wargame` as the iOS app, so both can share one App
Store record as a universal purchase. It runs the same screens as the
browser: keyboard and mouse, no touch controls (they appear after the first
touch, as in the browser), the start page as on a large screen. It starts in
full screen every time (state restoration is off, so macOS cannot reopen it
as a window); View > Exit Full Screen or ⌃⌘F leaves it for a 1280 x 800
window that keeps at least 720 x 480.

Game controllers work as on the iPad: `macos/Runner/GamepadPlugin.swift`
reads them through GameController and streams them to the same
`lib/src/tv/tv_input.dart`, the first one steers the own tank, two of them
play on a split screen (see **Two players** below), and the display stays
awake during a round. Only pads with two sticks count. The menus stay with
keyboard and mouse, as in the browser. Phones pair as controllers too, the
Mac is the screen.

The app is sandboxed and asks for two things in `Runner/*.entitlements`:
outgoing connections (`network.client`, without it Supabase is out of reach
and the app plays offline) and the camera, for the QR code button in the room
list (`mobile_scanner`, text in `NSCameraUsageDescription`). Room links from
the web do not open the app yet: associated domains need a signed build with
a provisioning profile. `python3 store/tool/app_icon.py` also writes the Mac
icon set, the square on Apple's rounded plate with a shadow, since macOS does
not round icons itself.

```sh
flutter run -d macos
flutter build macos --release \
  --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=... --dart-define=ACCOUNTS=true
```

The build signs ad hoc, enough to run it on the Mac that built it. To hand it
on, open `macos/Runner.xcworkspace`, pick the team under Signing &
Capabilities and archive (Product > Archive): from the organizer either upload
to App Store Connect or export with Developer ID, which Xcode notarizes. CI
builds it unsigned next to the iOS app.

## Apple Vision Pro

Flutter has no visionOS build: there is no fork like flutter-tvos, and the
engine leans on `UIScreen`, which visionOS lacks. So the iPad app runs on the
Vision Pro as a compatible app in a window, and a pinch arrives as a tap where
the player looks. `GamepadPlugin.swift` answers `vision` on the `wargame/tv`
channel with `ProcessInfo.isiOSAppOnVision` (iOS 26.1), and
`lib/src/vision/vision_support.dart` keeps it as `onVision` before the game
starts. Branch on `onVision` only.

On the Vision Pro the round changes in three ways:

- **Look to aim, pinch to fire.** The right stick gives way to the whole
  window: a pinch aims the turret at the spot looked at (`TankGame.lookAt`,
  the same pointer the mouse sets) and fires while the fingers stay
  together. Moving the pinched hand does not move the aim, since visionOS
  reports the hand after the first touch. Grenades and the barrage land on
  that spot as they do on the mouse cursor. A pinch in the lower left still
  drives with the floating stick, so both hands play at once.
- **A still window.** The screen shake is off (a window rattling in the room
  makes people feel sick); the red edge of a hit stays.
- **Its own tutorial cards** for driving, looking and pinching.

Game controllers and a paired phone work as on the iPad. The simulator build
for iOS installs on an Apple Vision Pro simulator (visionOS runtime from Xcode
Settings > Components) with `xcrun simctl install`, runs online there and
reports `onVision`. Taps cannot be injected into that simulator, so looking
and pinching are tried by hand in its window, and not yet on a real headset.
A native shell with SwiftUI ornaments around the game would need Flutter on
visionOS first.

## Apple Watch

`watchos` is the watchOS runner of the same game, built with the
[flutter-watchos](https://github.com/flutterwatch/flutter-watchos) toolchain
(Flutter 3.47.5, Apple Silicon, `flutter-watchos login` once). The watch app is
a companion of the iOS app (`de.regetskcob.wargame.watchkitapp`, embedded by the
"Embed Prebuilt watchOS App" phase of the iOS Runner) and runs the same
`lib/main.dart`. State: first version, not tried on a real watch yet. The game starts in the watch Simulator and
reaches Supabase and plays its sounds (`audioplayers_watchos`,
`path_provider_watchos`, `shared_preferences_watchos`) and taps the wrist
(`lib/src/haptics.dart`: hits and blasts close by, countdown, start, own tank
destroyed, round won or lost).

The watch has its own screens (`lib/src/watch`), used instead of the phone
overlays when `FlutterWatchosPlatform.isWatch`: a start page with the call sign
(a tap opens the watch keyboard), the three ways to play and the open rooms,
a waiting room with vehicle, level and public or private, a slim HUD (tanks
left or wave, armour, magazine, up to three inventory items, in a defense
round a button to build a gun), and an end screen. The Digital Crown scrolls
the menus. In a round it steers: the tank drives all the time and fires by
itself at the nearest enemy (the aim assist, on hard the gun fires straight
ahead), and turning the crown turns the direction of travel. The crown reports scroll
distance with the system's acceleration (about 0.75 per detent, thousands for
a flick), so `WatchSteering.steer` takes its logarithm: a detent corrects by
about two degrees, a quick turn swings at full speed. The heading stays within
`maxLead` of the hull, so the tank never overshoots far or turns the wrong way
round. Measured in the watch Simulator through Device Hub, still to be tried
on a real watch. The watch camera looks 12 % closer than the phone's
(`GameConfig.watchZoom`), and in a solo round every tank tops out 15 % slower
(`GameConfig.watchSoloSpeed`), since the crown steers slower than a thumb;
shared rounds keep the same speed for all. The watch plays as a guest, signing in takes the phone.
The app icon is the one of the phone app.

```sh
export PATH="$HOME/path/to/flutter-watchos/bin:$PATH"
flutter-watchos build watchos --simulator    # debug, Simulator only
flutter-watchos run -d <watch-simulator-id>  # hot reload
flutter-watchos run -d <watch-id> --release  # real watch: Series 9+, watchOS 26+
```

For the App Store, `tool/archive_ios.sh` builds the watch app first, then the
iOS archive, checks that `Panzergefecht.app/Watch/Runner.app` is inside with
the same version and build, and copies the archive into the Organizer as
"Panzergefecht <version> (<build>)"; with `--upload` it also sends it to App
Store Connect. The embed phase
(`tool/embed_watch_app.sh`) stops an archive without a watch app or with a
stale one; `ALLOW_NO_WATCH=1` lets one through on purpose. Older watches
(Series 4 to 8, SE 1/2, Ultra 1) get the stub slice flutter-watchos adds, which
only says that the app needs a Series 9.

CI (job `watchos` in `ci.yaml`) builds the watch app for the Simulator with
the toolchain tag `v3.47.5-watchos.0.1.1`, which needs no account, so a
broken watch build shows up there. Release builds need a signed-in
`flutter-watchos` account and stay local (`tool/archive_ios.sh`); the
`testflight` workflow cannot build the watch app.

Use `onWatch` from `lib/src/watch/watch_support.dart` to branch for a watch
(the Apple Watch or Wear OS), `FlutterWatchosPlatform.isWatch` only for what
is Apple's alone, never `Platform.isWatchOS` in shared code. Plugins need a `*_watchos`
package; without one calls throw `MissingPluginException`.
`app_links`, `share_plus` and `mobile_scanner` have none, so no room links, no
sharing and no QR scanning on the watch.

## Wear OS

A Wear OS watch (Galaxy Watch 4 and later, Pixel Watch) runs the Android
app itself. Before the game starts, `detectWear` asks `WearPlugin.kt` whether
the device has `FEATURE_WATCH`; then `onWear` and `onWatch` are true and the
watch gets the same screens and crown steering as the Apple Watch. Other
watches (Garmin, Huawei, Fitbit) cannot run Flutter and get nothing.

Flutter's Android embedding only takes motion events from pointing devices
and drops the rotary encoder of a watch. `MainActivity` hands those events to
`WearPlugin.kt`, which streams them to `WearCrown` (`lib/src/watch/wear_crown.dart`)
as detents (forward positive, one per click of a Galaxy bezel) and the
system's scroll distance for them. Between rounds `WearCrown` turns them into
scroll events in the middle of the screen, so the menus scroll as native
lists do; while a round runs it keeps the detents for `WatchSteering`.
Without the Digital Crown's acceleration one click turns the heading by
`bezelTurn` (15 degrees, as far as the bezel itself turns), and the heading
may run up to `bezelMaxLead` (135 degrees) ahead of the hull, so a quarter
turn of the bezel turns the tank a quarter however quick the hand was.

The wrist is tapped for the same moments as on the Apple Watch
(`lib/src/haptics.dart`): `WearHaptics` asks `WearPlugin.kt` to vibrate, a
click for a countdown second or a hit close by, a heavy click for a heavy
hit, a 150 ms pulse for the start, two short pulses for a win and a long
double for the own tank destroyed or a lost round. Only the Wear OS manifest
asks for `VIBRATE`, the phone build stays without it.

On a round screen (`watchRound`, from Android's `isScreenRound`) the
screens keep to the circle. `watchInsets` keeps the menus inside the largest
square of the circle. The HUD draws armour and magazine as arcs along the rim
(`WatchRimPainter`: armour on the left, the magazine on the right, both
filling from the bottom, no magazine arc when shells never run out), puts the
status at the top, the inventory on a ring above the bottom with the first
slot on the left, and in a defense round the build button under the own
tank. The Apple Watch keeps its rectangular layout.

The Wear OS build is the Android app with `-P wear=true`: it merges the
manifest of the library module `android/wear/` (`android.hardware.type.watch`,
`com.google.android.wearable.standalone`, `VIBRATE`), raises minSdk to 30 (Wear OS 3)
and adds 100000 to the version code. Play takes it as a form factor of its
own with `wear:` tracks, uploaded through the `play` workflow with
`form_factor: wear` (see `store/android/README.md`). The phone bundle carries
none of this. CI and `tool/verify.sh` build both.

State: tried in the Wear OS 6 emulator (small round, 384 px), not on a real
watch yet; the Wear OS form factor still has to be added in the Play Console.

```sh
sdkmanager "system-images;android-36;android-wear-signed;arm64-v8a"
avdmanager create avd -n Wear_Round_API36 \
  -k "system-images;android-36;android-wear-signed;arm64-v8a" -d wearos_small_round
emulator -avd Wear_Round_API36
flutter run -d emulator-5554 --android-project-arg=wear=true
adb shell input scroll --axis SCROLL,-1    # one click of the bezel, clockwise
```

## Apple TV

All televisions, Android TV and Fire TV included, are summed up in
[tv.md](tv.md).

`tvos` is the tvOS runner of the same game, built with the
[flutter-tvos](https://github.com/fluttertv/flutter-tvos) toolchain (Flutter
3.47.6, no account needed). It runs the same `lib/main.dart` and the same
screens as the browser, drawn larger (`tvScale`), and shares the bundle id
`de.regetskcob.wargame` with the iOS app, so both can be one universal
purchase. Icon, top shelf and launch screen come from the layers of the app
icon (`store/tool/tv_icons.py`). State: tried in the Apple TV Simulator only.

Nothing scrolls on the television. The menus use its width: the start page puts
the controllers, the phone pairing and the leaderboard in a column beside the
four ways to play, the account sheet has two columns, and a page that is still
too tall shrinks to fit (`FitOrScroll`) instead of scrolling. Only the legal
texts scroll.

It plays with the Siri Remote or a game controller, whichever is in hand:

| | Controller | Siri Remote |
| --- | --- | --- |
| Drive | left stick, the tank turns and drives that way | thumb on the touch surface, where it rests is the direction |
| Aim | right stick, released the aim assist takes over | aim assist (none on hard) |
| Fire | R2 or A | click |
| Special weapon | L2 | play/pause |
| Inventory | X, Y, then ←, ↑, →, ↓ for slots 1 to 6 | play/pause, the top slot, when no weapon is armed |
| Defense | R1 builds or upgrades, L1 switches the gun | play/pause builds while the inventory is empty |
| Menus | pad or stick, A selects, B back | swipe, click selects, Menu back |

`tvos/Runner/GamepadPlugin.swift` reads both through GameController and streams
them to `lib/src/tv/tv_input.dart`, which steers the tank in a round and keeps
the screen saver away. The menus take the arrow keys and enter the engine makes
of swipes and presses: up and down walk them in reading order, an amber frame
(`lib/src/tv/tv_focus_frame.dart`) shows the focus, and Menu or B steps back
from the settings to the waiting room to the start page and leaves the app only
from there. In a round they do nothing. The Apple TV can also pair phones as
controllers, like the browser: the first steers the game, a second waits for a
duel. No camera, so no QR scanning, and no room links. The briefing explains
the controls of what is in hand, the controller or the Siri Remote, and
switches when another one is picked up. The menus sit in the middle of the
screen.

**Two players** on the Apple TV, in the browser, on an iPad or Android
tablet and on the Mac: with two
controllers in (or phones, the Siri Remote counting as one, handed out
controllers first, then phones, the remote last), the second player gets a game of their own (`lib/src/tv/second_player.dart`) that
joins the first player's room. Rounds then play on a split screen, side by side
or, on a tablet held upright, one above the other, each half from its own tank
(`lib/src/tv/split_view.dart`); the menus stay with the first player. Single
player puts both against the CPU tanks, multiplayer and defense take both
pilots along, and capture the flag puts both on the same side against the
CPU tanks or, as the host picks in the settings, one red and one blue, with
CPU tanks evening out the sides. The browser reads controllers through its Gamepad API
(`lib/src/tv/web_pads.dart`, a controller shows once a button on it was
pressed), the iPhone and iPad through GameController (`ios/Runner/GamepadPlugin.swift`),
the Mac the same way (`macos/Runner/GamepadPlugin.swift`), and Android from
the key and motion events of its gamepads, which `MainActivity` hands to
`android/.../GamepadPlugin.kt` (same channels and state as on iOS; not yet
tried with a real controller).
Phones are too small for two halves. One controller alone, a phone or a
game controller, steers the own tank in every mode, and the touch sticks of
a tablet step aside for it. On a computer, in the browser or the Mac app,
the keyboard and mouse can be the first player's seat: with one controller
or phone in, the controllers panel on the start page offers "two with the
keyboard" (`KeyboardSeat` in `lib/src/tv/seats.dart`), and the controller
or phone steers the second half. It is off until switched on, so somebody
alone with a controller keeps the whole screen. The keyboard only reaches
the first player's game, which holds the focus.

The two games talk on the device (`LocalLink` in `net_service.dart`): nothing
goes over Realtime and the room takes no slot. The first player's presence
carries the second's, so people on other devices count them, and a room of two
is full for them. Only with somebody from another device in the room does the
second player join over a Supabase connection of their own, between rounds,
and the room costs what any room of that many pilots costs.

**Duel** (fourth card on the start page with two players): a defense round with
a base at either end of the road of a common layout
(`DefenseMap.duelForSeed`), red on the left, blue on the right. The waves stay
as they are, but each side's roll along the road against the other's base, so
they meet on the way, and every gun, tank and squad fights the other side. Y on
a controller, T on a keyboard, sends an extra tank against the other base for
120 funds (`troops` event, run by the host). Bases grow on their
own. Two players on one screen watch their duel on the whole field at once
instead of a split screen: the camera holds still over the map
(`TankGame.overview`), the wave and both bases on top, each player's tank,
funds and inventory in their corner (`lib/src/tv/duel_hud.dart`). Whose base
falls first loses, and the waves go on past
wave 8 by themselves. Duels are unranked. The host runs the waves and keeps the
score of every base and gun, also of the other player's shots. Phones as
the two players' controllers talk to the television on a lane each.

```sh
export PATH="$HOME/path/to/flutter-tvos/bin:$PATH"
flutter-tvos build tvos --debug --simulator  # debug, Simulator only
flutter-tvos run -d <apple-tv-simulator-id>  # hot reload
flutter-tvos run -d <apple-tv-id> --release  # real Apple TV
python3 store/tool/tv_icons.py               # icon layers, top shelf, launch image
```

Use `onTv` from `lib/src/tv/tv_input.dart` to branch for a television (the
Apple TV and Android TV), `onAppleTv` for the Apple TV alone, never
`Platform.isIOS` alone: it is true there as well. Plugins need a `*_tvos`
package (`shared_preferences_tvos`, `path_provider_tvos`, `audioplayers_tvos`,
`url_launcher_tvos` are in), `app_links`, `share_plus` and `mobile_scanner`
have none. Run `flutter-tvos` after a plain `flutter pub get` or `flutter test`
before a hot restart: both write the Dart plugin registrant for iOS, which
breaks the sound on the Apple TV until the next `flutter-tvos` build.

