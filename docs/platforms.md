# Platforms

One Flutter code base, one `lib/main.dart`, runs the game in the browser and
as apps on iOS and iPadOS, Android, the Mac, the Apple Watch, Wear OS, the
Apple TV and Android TV, and (as the iPad app) on the Apple Vision Pro. This
page is for developers who want to run the game on a given platform or need
to know what is special there: how to start it, what differs from the
browser, what has been tried and what has not. Televisions have a page of
their own, [tv.md](tv.md). How the game plays is in
[gameplay.md](gameplay.md), the network side in [netcode.md](netcode.md),
tests and deployment in [development.md](development.md).

Contents:

- [At a glance](#at-a-glance)
- [Web](#web)
- [iOS and Android](#ios-and-android)
- [Home screen widget](#home-screen-widget)
- [iMessage](#imessage)
- [Mac](#mac)
- [Apple Vision Pro](#apple-vision-pro)
- [Apple Watch](#apple-watch)
- [Wear OS](#wear-os)
- [Apple TV](#apple-tv)
- [Controllers and two players on one screen](#controllers-and-two-players-on-one-screen)
- [Writing code for several platforms](#writing-code-for-several-platforms)
- [Release builds (maintainer)](#release-builds-maintainer)

## At a glance

| Platform | Folder | Run it | State |
| --- | --- | --- | --- |
| Web | `web/` | `flutter run -d chrome` | Live at <https://panzergefecht.de/play/> |
| iPhone, iPad | `ios/` | `flutter run -d <device-id>` | Plays; tried on a real iPhone and iPad |
| Android phones, tablets | `android/` | `flutter run -d <device-id>` | Plays; game controllers not tried on a real pad |
| Mac | `macos/` | `flutter run -d macos` | Plays |
| Apple Vision Pro | the iPad app | install the iOS simulator build | Simulator only; look and pinch not tried on a headset |
| Apple Watch | `watchos/` | `flutter-watchos run` | Watch Simulator only |
| Wear OS | `android/` + `android/wear/` | `flutter run --android-project-arg=wear=true` | Wear OS emulator only |
| Apple TV | `tvos/` | `flutter-tvos run` | Apple TV Simulator only, see [tv.md](tv.md) |
| Android TV, Fire TV | the Android app | `flutter run -d <device-id>` | Android TV emulator only, see [tv.md](tv.md) |

Every build talks to the hosted Supabase project unless you pass your own
(`--dart-define=SUPABASE_URL=...` and `--dart-define=SUPABASE_KEY=...`, see
[`lib/src/app/env.dart`](../lib/src/app/env.dart)). A fork that runs its
own backend passes these to every build below. Without a reachable server the
game still starts and plays alone against CPU tanks (`ServerStatus`, see
[netcode.md → Running without the server](netcode.md#running-without-the-server)).

## Web

The browser game is the main target and the reference for every other
platform. Push to `main` deploys it with GitHub Pages under `/play/` of the
landing page ([development.md → Deploying](development.md#deploying)).

```sh
flutter run -d chrome --dart-define=ROOM=dev   # start twice for two players
flutter build web --no-web-resources-cdn --base-href /play/
```

What is special in the browser:

- **Rooms live in the address**: `?room=CODE` before the `#`, so a link or a
  QR code leads into the same room from any device.
- **Keyboard and mouse** play; touch sticks appear after the first touch.
  Game controllers come in through the Gamepad API
  ([`lib/src/tv/web_pads.dart`](../lib/src/tv/web_pads.dart)); a controller
  shows up once one of its buttons was pressed, as browsers require.
- **Sound** runs through a limiter against crackling
  (`lib/src/audio/audio_backend_web.dart`), and a mute button sits beside
  the account. The apps on phones have none: there the silent switch and
  the volume keys decide.
- **Loading**: `web/index.html` shows the launch picture (the tank of the
  app icon on its ground) before Flutter starts. It loads the pictures from
  the built assets under `assets/assets/images/`, so Flutter's own
  `LoadingView` ([`lib/src/ui/loading_view.dart`](../lib/src/ui/loading_view.dart))
  finds them in the browser cache and takes over without a flash.
- **The browser pairs phones as controllers but never is one**, see
  [The phone as a controller](#the-phone-as-a-controller).

## iOS and Android

The apps are called Panzergefecht, with the id `de.regetskcob.wargame` on
both stores (kept from an earlier name, since store ids cannot change). The
iOS product is `Panzergefecht.app`; the Xcode target and scheme stay
`Runner`, which `flutter build ios` expects.

### Running

You need a full Xcode for iOS and a JDK with the Android SDK for Android
(`flutter doctor` tells you what is missing).

```sh
flutter run -d <device-id>          # a simulator, an emulator or a phone
flutter build ios --release         # set a signing team first, see below
flutter build apk --release
flutter build appbundle --release
```

To play against a local Supabase stack (`supabase start`) from the Android
emulator, use `http://10.0.2.2:54621` as `SUPABASE_URL`; from a real phone,
the LAN address of your computer.

**Signing for iOS** (and every other Apple platform) is set once in
[`apple/Signing.xcconfig`](../apple/Signing.xcconfig): team, automatic
signing, development certificate. Each Xcode project includes it, and no
`project.pbxproj` carries signing settings of its own (only `tvos/` repeats
the team, because flutter-tvos reads it from there). To sign with your own
team, add your Apple ID in Xcode (Settings > Accounts) and put
`DEVELOPMENT_TEAM = <your team id>` into `apple/Signing.local.xcconfig`,
which git ignores and which overrides the shared file.
`CODE_SIGN_IDENTITY = -` there signs ad hoc. Leave the team field in Xcode's
Signing & Capabilities alone: it writes into the project and wins over the
shared file.

**Signing for Android**: without `android/key.properties` Gradle signs
release builds with the debug key, which is fine for trying but rejected by
Google Play. Copy `android/key.properties.example` and point it at your own
upload key. Never commit the file.

### What is special on phones and tablets

- **Orientation**: the game plays upright or sideways and hides the system
  bars. The camera shows the same stretch of the world along the shorter
  side, so upright shows more of the field above and below; upright phones
  look 20 % closer outside defense rounds (`GameConfig.uprightPhoneZoom`).
- **Touch sticks** on the screen, or a game controller, which takes over
  until the screen is touched again (`TankGame.touchOverPad`).
- **Tablets are decided by size, not platform**: a shorter side of 600
  points or more (`tabletShortSide` in
  [`lib/src/ui/widgets/tablet_scale.dart`](../lib/src/ui/widgets/tablet_scale.dart)).
  Tablets lay the start page and the waiting room out in columns from 1000
  points of width, and large tablets draw menus and HUD larger
  (`MenuScale`, up to 1.25 on a 13" iPad via `menuScaleFor`). Phones, the
  11" iPad and a 1280 × 800 browser keep a scale of 1. The browser and the
  Mac keep a centred menu of at most 1040 points.
- **The account page** is a route of its own over the game (`/account`,
  [`lib/src/ui/account_page.dart`](../lib/src/ui/account_page.dart)); from
  760 points of width it shows the account and this device's settings side
  by side.
- **Vibration** ([`lib/src/haptics.dart`](../lib/src/haptics.dart), Flutter's
  `HapticFeedback`): a light tap for a blast close by, a hard knock for a
  heavy hit, the own tank destroyed and the end of a round, a click per
  countdown second and a firm tap at the start. The player's own moments
  always tap; blasts on the field at most twice a second and never right
  after an own tap (`Haptics.admits`), so a late defense wave does not buzz
  without pause. Phones get a switch on the account page; iPads and most
  Android tablets have no motor and show none.
- **Sound** ([`lib/src/audio/sound_mixer.dart`](../lib/src/audio/sound_mixer.dart))
  follows the silent switch and mixes with music from other apps. Sounds
  on the field fall off with the square of the distance and share a budget
  of five per quarter second. Each native player call crosses to the main
  thread, and restarting an iOS player halfway took up to 19 seconds in a
  late wave, so `VoiceTraffic` gives each sound a few voices, never cuts off
  a louder one, and drops any sound not started within 120 ms rather than
  playing it late. `EngineThrottle` changes the engine loop only when the
  speed moves by a twentieth. Measurements are in
  [development.md → Device QA](development.md#device-qa).
- **Room links**: on iOS, links to `panzergefecht.de` with `?room=` or
  `?pad=` open the app (associated domains in `Runner.entitlements`, the
  file `store/ios/apple-app-site-association` on the site), and the scheme
  `panzergefecht://` serves the iMessage extension. Android has no app
  links: room links open the browser game there. A fork with its own domain
  replaces both entries and hosts its own association file.
- **Sign-in mails** are confirmed with the code from the mail in the apps;
  the link in the mail opens the web game.
- **A fast start**: the start page does not wait for the server. A first
  visit signs in as a guest in the background (`ServerStatus.ensureSession`),
  the call sign kept on the device shows at once (`rememberPilot`), and the
  sounds load after the first frame.
- **Launch screen**: the tank of the app icon on its ground, held by
  `LoadingView` until the game has loaded. Android draws the ground colour
  (`@color/launch_ground`) and, from Android 12, the system splash shows the
  tank as its icon (`values-v31/styles.xml`). All launch images and icons
  come from the design system Horizont: `python3 tool/store/horizont_icons.py`
  copies them into every platform folder.

## Home screen widget

`ios/OnlineWidget` is a WidgetKit extension in Swift that shows how many
pilots are online, how many are in a round and how many rounds were played
today. It comes in the small and medium home screen sizes and the three
lock screen sizes.

- **Where the number comes from**: every running game calls the RPC
  `ping_online` once a minute (`lib/src/db/online_service.dart`, migration
  0013). The widget asks `online_status`, which only returns counts, so
  nobody learns who is online.
- **Refresh**: every ten minutes, five after a failed request; WidgetKit
  hands out only a few dozen refreshes a day.
- **Forks**: the widget cannot read the Dart defines. It asks the project
  in [`apple/App.xcconfig`](../apple/App.xcconfig), which mirrors the
  defaults of `lib/src/app/env.dart` (a test keeps the two equal).

To try it, run the iOS app in the simulator, then add the widget from the
home screen's edit mode.

## iMessage

`ios/MessagesExtension` is a Messages extension in plain Swift and SwiftUI
that ships inside the iOS app. It only invites; the game never runs in
Messages. Flutter recommends at least 100 MB for an extension's UI, Messages
ends extensions that take too much without warning, and it starts one
instance per interactive bubble, so a Flutter view there was not an option.

How an invitation works:

1. The extension offers what fits the chat, read from
   `remoteParticipantIdentifiers` (Messages hides who the people are). A chat
   for two gets defense together, the base duel and Last Tank Standing; a
   group gets Last Tank Standing and capture the flag, with a note when the
   chat has more people than a room holds (four, as the default of
   `MAX_PILOTS`; later ones watch).
2. A choice puts a bubble with a fresh room code into the input field. Its
   link is the usual room link plus the mode, for example
   `https://panzergefecht.de/play/?room=CODE&mode=defense`, so it opens the
   browser game on a phone without the app.
3. Once the player sends it, the extension opens the app at
   `panzergefecht://play?room=CODE&mode=defense&host=1`. An extension may
   only open its own app. `listenForRoomLinks` (`room_stub.dart`) opens the
   room as its host and `chooseInvitedMode` skips the start page in that
   mode: `multi`, `flag`, `defense` or `duel`.
4. Tapping the bubble opens the extension with a button into the room. The
   sender goes back in as host: the extension remembers the rooms it sent in
   its own `UserDefaults`, because the simulator gives the sender of a message
   a different participant id than the local player. Everybody else joins
   as a guest.
5. When a round ends, `ChatResultPlugin.swift` (fed by
   [`lib/src/app/chat_result.dart`](../lib/src/app/chat_result.dart))
   writes the result as `ChatResult` (`ios/Shared`) into the app group
   (`APP_GROUP` in `apple/App.xcconfig`). The next time the extension opens in that
   chat it offers the newest result of a room from there, if it is less
   than a day old. Sent, it replaces the invitation bubble in the same
   session; the link still leads into the room for another round.

Guests learn the mode when the round starts, as in every room. While the
host's app sits behind Messages, a guest who came in first stands in as host
and hands back when the owner returns.

To try it, run the iOS app in the simulator, open Messages, a chat with one
of the fake contacts and the app list behind "+". After installing a new
build, quit Messages once, or it keeps the old extension. The bubble pictures
come from `python3 tool/store/imessage.py`, the icons from
`tool/store/horizont_icons.py`.

**Not tried yet:** two real devices in one chat, and a group chat on real
devices.

## Mac

`macos/` builds `Panzergefecht.app` with the same bundle id as the iOS app,
so both can share one App Store record. It runs the browser's screens:
keyboard and mouse, the touch sticks only after a touch.

```sh
flutter run -d macos
```

What is special on the Mac:

- **Full screen at every start**: state restoration is off, so macOS cannot
  reopen it as a window. View > Exit Full Screen (⌃⌘F) leaves it for a
  1280 × 800 window of at least 720 × 480.
- **Game controllers** through GameController
  (`macos/Runner/GamepadPlugin.swift`), streamed to the same
  [`lib/src/tv/tv_input.dart`](../lib/src/tv/tv_input.dart) as on the Apple
  TV. Only pads with two sticks count. The menus stay with keyboard and
  mouse.
- **Sandboxed**, with two entitlements in `macos/Runner/*.entitlements`:
  outgoing connections (`network.client`; without it the app plays offline)
  and the camera for the QR button in the room list (`mobile_scanner`).
- **Room links** open the app as on iOS (the same associated domains;
  `AppDelegate.swift` hands the activity to `app_links`). Links clicked in
  Messages, Mail or Notes open the app; `open` in the Terminal always goes
  to the browser. A pairing link (`?pad=`) only says that phones are the
  controllers. Associated domains need a real certificate, so the ad hoc
  CI build deletes them from the entitlements first.
- **Icon**: the square icon on Apple's rounded plate with a shadow, since
  macOS does not round icons itself.

## Apple Vision Pro

Flutter has no visionOS build (no fork like flutter-tvos, and the engine
relies on `UIScreen`, which visionOS lacks). So the iPad app runs on the
Vision Pro as a compatible app in a window, where a pinch arrives as a tap
at the spot the player looks at. `ios/Runner/GamepadPlugin.swift` answers
`vision` on the `wargame/tv` channel with `ProcessInfo.isiOSAppOnVision`
(iOS 26.1), and [`lib/src/vision/vision_support.dart`](../lib/src/vision/vision_support.dart)
keeps the answer as `onVision` before the game starts.

On the Vision Pro a round changes in three ways:

- **Look to aim, pinch to fire.** A pinch anywhere aims the turret at the
  spot looked at (`TankGame.lookAt`, the same pointer the mouse sets) and
  fires while the fingers stay together. Moving the pinched hand does not
  move the aim, since visionOS reports the hand only at the first touch. A
  pinch in the lower left still drives with the floating stick, so both
  hands play at once.
- **A still window.** No screen shake: a window rattling in the room makes
  people feel sick. The red edge of a hit stays.
- **Its own tutorial cards** for driving, looking and pinching.

To try it, install the iOS simulator build on an Apple Vision Pro simulator
(visionOS runtime from Xcode Settings > Components) with
`xcrun simctl install`. It runs online there and reports `onVision`. Taps
cannot be injected into that simulator, so look and pinch are tried by hand.

**Not tried yet:** a real headset. A native shell with SwiftUI ornaments
around the game would need Flutter on visionOS first.

## Apple Watch

`watchos/` is the watchOS runner of the same game, built with the
[flutter-watchos](https://github.com/flutterwatch/flutter-watchos) toolchain
(tag `v3.47.5-watchos.0.1.1`, Apple Silicon; release builds need
`flutter-watchos login` once). The watch app
(`de.regetskcob.wargame.watchkitapp`) is a companion embedded in the iOS app
and runs the same `lib/main.dart`. It needs a Series 9 or later on watchOS
26; older watches get a stub that says so.

```sh
export PATH="$HOME/path/to/flutter-watchos/bin:$PATH"
flutter-watchos build watchos --simulator    # debug, Simulator only
flutter-watchos run -d <watch-simulator-id>  # hot reload
flutter-watchos run -d <watch-id> --release  # a real watch
```

What is special on the watch:

- **Screens of its own** ([`lib/src/watch`](../lib/src/watch)): a start page
  with the call sign (a tap opens the watch keyboard) and the four ways to
  play, a waiting room with vehicle, difficulty and public or private, a
  slim HUD (tanks left or wave, armour, magazine, up to three items, a build
  button in defense) and an end screen.
- **Crown steering**: the tank drives all the time and the aim assist fires
  at the nearest enemy; turning the Digital Crown turns the direction of
  travel. The crown reports scroll distance with the system's acceleration,
  so `WatchSteering.steer` takes its logarithm: a detent corrects by about
  two degrees, a quick turn swings at full speed, and the heading stays
  within `maxLead` of the hull. Between rounds the crown scrolls the menus.
- **Closer and slower**: the camera looks 12 % closer
  (`GameConfig.watchZoom`), and in a solo round every tank tops out 15 %
  slower (`GameConfig.watchSoloSpeed`), since the crown steers slower than
  a thumb. Shared rounds keep the same speed for all.
- **Alone against CPU tanks in every mode**: watchOS gives an app no
  WebSocket, so `NetService(offline: true)` leaves out the room channel and
  the room list. The player is the room's only member and host.
- **Rounds count for the iPhone's account**
  ([`lib/src/watch/account_link.dart`](../lib/src/watch/account_link.dart),
  WatchConnectivity via `flutter_watch_link`). The phone sends who is signed
  in and the current access token on every session change. Only the access
  token travels, never the refresh token: Supabase rotates refresh tokens on
  every use, and two devices sharing one would sign each other out. The
  watch records rounds with that token (`LinkedScores`, `LinkedProfiles`);
  a round that ends after the token expired (an hour) waits on the watch
  (`PendingRounds`, up to 30) together with its round ticket and goes in,
  nine seconds apart, once the phone sends a fresh token.
- **Haptics** for hits and blasts close by, the countdown, the start, the
  own tank destroyed and the end of a round.
- **Missing plugins**: `app_links`, `share_plus` and `mobile_scanner` have
  no watchOS package, so no room links, sharing or QR scanning.

In the paired simulators the phone's context arrives, but the watch's own
request fails with "Companion app is not installed" (a simulator limit).
Both apps must come from the same build. CI builds the watch app for the
simulator when the `watchos` box is ticked on a manual run of `ci`.

**Not tried yet:** a real watch, including crown steering.

## Wear OS

A Wear OS watch (Galaxy Watch 4 and later, Pixel Watch) runs the Android
app itself. Before the game starts, `detectWear` asks `WearPlugin.kt`
whether the device has `FEATURE_WATCH`; then `onWear` and `onWatch` are true
and the watch gets the same screens and crown steering as the Apple Watch.
Other watches (Garmin, Huawei, Fitbit) cannot run Flutter.

```sh
sdkmanager "system-images;android-36;android-wear-signed;arm64-v8a"
avdmanager create avd -n Wear_Round_API36 \
  -k "system-images;android-36;android-wear-signed;arm64-v8a" -d wearos_small_round
emulator -avd Wear_Round_API36
flutter run -d emulator-5554 --android-project-arg=wear=true
adb shell input scroll --axis SCROLL,-1    # one click of the bezel, clockwise
```

What is special on Wear OS:

- **A build of its own**: `wear=true` merges the manifest of the library
  module `android/wear/` (`android.hardware.type.watch`, standalone,
  `VIBRATE`), raises minSdk to 30 (Wear OS 3) and adds 100000 to the version
  code, so Google Play takes it as a separate form factor. The phone bundle
  carries none of this; a watch feature in it would hide the app from
  phones.
- **The rotary input**: Flutter's Android embedding drops it, so
  `MainActivity` hands it to `WearPlugin.kt`, which streams detents to
  `WearCrown` ([`lib/src/watch/wear_crown.dart`](../lib/src/watch/wear_crown.dart)).
  Between rounds they become scroll events; in a round one click turns the
  heading by `bezelTurn` (15°), up to `bezelMaxLead` (135°) ahead of the
  hull, because there is no crown acceleration to read.
- **Round screens** (`watchRound`, from Android's `isScreenRound`): menus
  stay inside the largest square of the circle (`watchInsets`), and the HUD
  draws armour and magazine as arcs along the rim (`WatchRimPainter`). The
  Apple Watch keeps its rectangular layout.
- **Vibration** through `WearHaptics` and `WearPlugin.kt`, for the same
  moments as on the Apple Watch.

**Not tried yet:** a real watch. The Wear OS form factor still has to be
added in the Play Console.

## Apple TV

`tvos/` is the tvOS runner, built with the
[flutter-tvos](https://github.com/fluttertv/flutter-tvos) toolchain. It runs
the same screens as the browser, drawn larger, with the Siri Remote or a game
controller, and shares the bundle id of the iOS app. Everything about it
(running it, the controls, the focus, the round menu, what is untested) is in
[tv.md → Apple TV](tv.md#apple-tv), together with Android TV and Fire TV.

Two players on one screen and the base duel started on the Apple TV but run
on several platforms; they are described below.

## Controllers and two players on one screen

### Game controllers

One game controller steers the own tank in every mode, in the browser, on
iPhone, iPad, Android, the Mac and the televisions. The native side reads it
and streams it to [`lib/src/tv/tv_input.dart`](../lib/src/tv/tv_input.dart):

| Platform | Reads controllers with |
| --- | --- |
| Browser | Gamepad API, [`lib/src/tv/web_pads.dart`](../lib/src/tv/web_pads.dart) |
| iPhone, iPad, Vision Pro | GameController, `ios/Runner/GamepadPlugin.swift` |
| Mac | GameController, `macos/Runner/GamepadPlugin.swift` |
| Apple TV | GameController, `tvos/Runner/GamepadPlugin.swift` (also the Siri Remote) |
| Android, Android TV | key and motion events from `MainActivity` to `GamepadPlugin.kt` |

Android with a real controller has not been tried yet.

### The phone as a controller

The app on a phone can steer the game on a computer, tablet or television:
the screen shows a pairing QR code, the phone scans it (Account, Use as
controller) and shows the sticks, the gauges and, in defense, the shop. Only
the app on a phone becomes a controller (shorter side under 600 points); the
browser game and tablets pair phones, they never are one. What the phone
shows is in [gameplay.md](gameplay.md); the channels (`pad-<CODE>`, one lane
per phone) and their message budget are in
[netcode.md → Realtime limits](netcode.md#realtime-limits).

### Two players on one screen

On the Apple TV, in the browser, on an iPad or Android tablet and on the
Mac, two controllers give the second player a game of their own
([`lib/src/tv/second_player.dart`](../lib/src/tv/second_player.dart)) that
joins the first player's room. Phones count as controllers; seats go to game
controllers first, then phones, the Siri Remote last. Phones themselves are
too small for two halves.

- **Split screen**: rounds play side by side or, on a tablet held upright,
  one above the other, each half following its own tank
  ([`lib/src/tv/split_view.dart`](../lib/src/tv/split_view.dart)). The
  menus stay with the first player.
- **Modes**: single player puts both against CPU tanks, multiplayer and
  defense take both pilots along, and capture the flag puts both on one
  side or, as the host picks, one red and one blue, with CPU tanks evening
  out the sides.
- **Keyboard as a seat**: in the browser and the Mac app, with one controller
  or phone in, the controllers panel offers "two with the keyboard"
  (`KeyboardSeat` in [`lib/src/tv/seats.dart`](../lib/src/tv/seats.dart)).
  It is off by default, so somebody alone with a controller keeps the whole
  screen.
- **No Realtime cost**: the two games talk on the device (`LocalLink` in
  `lib/src/net/net_service.dart`), and the room takes no slot. The first
  player's presence carries the second's, so others count both. Only when
  somebody from another device joins does the second player connect to
  Supabase on their own, between rounds.

### Duel

With two players on one screen the start page shows a fourth card, the duel:
a defense round with a base at either end of the road
(`DefenseMap.duelForSeed`), red on the left, blue on the right. Each side's
waves roll against the other's base, and every gun, tank and squad fights the
other side. Y on a controller, T on a keyboard sends an extra tank for 120
coins (`GameConfig.troopCost`, event `troops`, run by the host). Instead of a
split screen the camera holds still over the whole map (`TankGame.overview`),
with each player's tank, coins and inventory in their corner
([`lib/src/tv/duel_hud.dart`](../lib/src/tv/duel_hud.dart)). Whose base falls
first loses; the waves go on past wave 8. Duels are unranked. The iMessage
extension offers the duel for chats of two.

## Writing code for several platforms

| Ask | For | Defined in |
| --- | --- | --- |
| `onTv` | every television (Apple TV, Android TV, Fire TV) | `lib/src/tv/tv_input.dart` |
| `onAppleTv` | the Apple TV alone (Siri Remote) | `lib/src/tv/tv_input.dart` |
| `onWatch` | every watch (Apple Watch, Wear OS) | `lib/src/watch/watch_support.dart` |
| `onWear` | Wear OS alone | `lib/src/watch/wear_crown.dart` |
| `FlutterWatchosPlatform.isWatch` | the Apple Watch alone | `flutter_watchos` |
| `onVision` | the iPad app on a Vision Pro | `lib/src/vision/vision_support.dart` |
| `tabletShortSide` | a tablet layout, by size | `lib/src/ui/widgets/tablet_scale.dart` |

Rules that save trouble:

- Never branch on `Platform.isIOS` alone: it is true on the Apple TV and the
  Vision Pro as well. Never use `Platform.isWatchOS` in shared code.
- Decide layouts by size, not by platform; the television, the watch and the
  Vision Pro are the exceptions above.
- A plugin needs a `*_tvos` or `*_watchos` package to work there
  (`shared_preferences`, `path_provider`, `audioplayers` have both,
  `url_launcher` has tvOS). `app_links`, `share_plus` and `mobile_scanner`
  have neither and throw `MissingPluginException` on the TV and the watch.
- Text fields go through `SelectToType`
  ([`lib/src/tv/select_to_type.dart`](../lib/src/tv/select_to_type.dart)),
  which keeps them read-only on a television until a click, see
  [tv.md](tv.md#apple-tv).
- After `flutter pub get` or `flutter test`, run `flutter-tvos` before a hot
  restart on the Apple TV: both write the Dart plugin registrant for iOS,
  which breaks the sound on the Apple TV until the next `flutter-tvos` build.

## Release builds (maintainer)

Release builds and uploads run on the maintainer's Mac only; CI just
validates. A fork uses its own store accounts, bundle ids and signing team
and can follow the same scripts. Every entry goes through
[`tool/release.sh`](../tool/release.sh); run it without arguments for the
list. Before an upload the [release test plan](release-test-plan.md) runs.

| Command | Builds |
| --- | --- |
| `tool/release.sh ios [--upload]` | the watch app, then the iOS archive with the watch app, widget and iMessage extension inside |
| `tool/release.sh macos [--upload]` | the Mac archive |
| `tool/release.sh tvos [--upload]` | the Apple TV archive |
| `tool/release.sh android phone\|wear [--upload <track>]` | a Google Play bundle for phones or Wear OS (fastlane) |

The Apple commands check version, Supabase address and team, put the archive
into Xcode's Organizer and with `--upload` send it to App Store Connect.
Details that matter:

- `tool/embed_watch_app.sh` stops an iOS archive without the watch app or
  with one of another version or build; `ALLOW_NO_WATCH=1` lets it through
  on purpose.
- flutter-tvos and flutter-watchos ship no dSYMs for `App.framework` and the
  engine, so uploads would warn "Upload Symbols Failed".
  `tool/make_dsym.sh` makes them while archiving (symbol tables, no line
  numbers), and the `ios` and `tvos` commands refuse an archive without
  them.
- flutter-tvos signs the engine with the Apple Distribution certificate
  (Apple rejects an unsigned one with ITMS-91065), so that certificate must
  be in the keychain. A tvOS development profile needs an Apple TV
  registered with the team.
- The apps declare no non-exempt encryption, so App Store Connect skips the
  export compliance question.
- Store texts, icons and screenshots live in `store/ios` and
  `store/android`, each with a README of what goes where.

A manual run of the `ci` workflow builds iOS without signing, the Mac ad hoc
signed, both Android bundles with the debug key and, when ticked, the watch
app; see [development.md → CI minutes](development.md#ci-minutes) for why it
does not run on every push.
