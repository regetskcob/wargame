# Televisions

Where the game stands on the big screen, what was found out about each TV
platform, and what is next. How the Apple TV build plays in detail
(controls, two players, the duel) is in
[platforms.md → Apple TV](platforms.md#apple-tv); this page is the overview
across all televisions.

## At a glance

| Platform | Devices | Build | State |
| --- | --- | --- | --- |
| Apple TV | Apple TV HD, 4K | `tvos/` (flutter-tvos) | Plays fully, tried in the Simulator only |
| Android TV / Google TV | Google TV Streamer, Chromecast with Google TV, Sony, Philips, TCL TVs … | the Android app | Plays in the Android TV emulator (Google TV, 4K); no real device yet |
| Fire TV on Fire OS | Fire TV Stick 4K Max, 4K Plus, Fire TV Cube, TVs with Fire TV built in | the Android app | Same build as Android TV; Amazon Appstore listing open |
| Fire TV on Vega OS | Fire TV Stick 4K Select (2025), Fire TV Stick HD (2026) | none yet | No Flutter; a web shell is worth a spike, see below |

## What all televisions share

`onTv` in `lib/src/tv/tv_input.dart` is true on every television and picks
the screens of the sofa: the larger menus (`tvScaleFor`), the amber focus
frame, Back stepping out of the menus, the controllers panel and the duel on
the start page, no touch sticks, no camera, no room links. `onAppleTv` is
only for what the Apple TV alone has, the Siri Remote and its settings.
`remoteName` names the remote on screen.

The menus are laid out 1371 points wide on every television
(`tvScaleFor`): the Apple TV is always 1920 points wide and draws them at
1.4, Android TV is mostly 960 wide (1080p at twice the density) and draws
them at 0.7. Both end up the same size on the panel, so the layouts tried on
the Apple TV hold.

## Android TV and Google TV

The Android app is the television app as well, one APK or bundle for phones,
tablets and televisions, the same way Google Play wants it.

Done:

- **Detection:** `detectTv()` asks `GamepadPlugin.kt` on `wargame/tv` →
  `info` before the game starts. Television means UI mode
  `UI_MODE_TYPE_TELEVISION`, the `android.software.leanback` feature or
  Fire OS's `amazon.hardware.fire_tv`.
- **Remote as a controller:** on a television `GamepadPlugin.kt` reports the
  remote as a pad of kind `remote`, last in the list like the Siri Remote.
  The d-pad drives (two keys at once drive diagonally), OK fires, play/pause
  or menu set off the special weapon or the top item and build a gun in
  defense. `MainActivity` hands it every key that is not from a gamepad;
  the keys still reach Flutter, so the d-pad walks the menus, OK presses
  (`LogicalKeyboardKey.select` is a default activator) and Back steps back
  through the same `PopScope` as on the Apple TV.
- **Game controllers** come through the gamepad path that already serves
  Android phones and tablets.
- **Manifest:** `LEANBACK_LAUNCHER`, a banner (`@drawable/tv_banner`, the tank of the Apple TV icon without the name, built
  by `store/tool/tv_icons.py`), and touch screen, camera, gamepad and
  leanback declared as not required, so Google Play and the Amazon Appstore
  list the app for televisions.
- **Texts:** the tutorial, the controls dialog, the duel help and the
  controllers panel speak of the d-pad and OK instead of the touch surface.

Open:

- Tried in the Google TV emulator (4K, 960×540 logical): the app shows on
  the home screen, the start page has the television layout with the
  remote as controller 1, the d-pad walks the focus, OK opens, Back steps
  back to the start page, and in a round the d-pad drives. Still to try:
  every menu and dialog, firing and items with a real remote, a game
  controller, the screen saver during a round (`keepAwake`), and a real
  device.
- Up from the first button does not wrap round to the last one, so
  reaching Start in the waiting room takes many presses down past the
  camouflage. Left and right could jump between the rows instead.
- Remotes without play/pause or menu (some Chromecast remotes) have no
  button for items and special weapons yet; a long press on OK could take
  it.
- Sign-in on a television: typing an e-mail with the d-pad is slow. A code
  shown on the TV and confirmed on the phone would fit better.
- Google Play: opt in to the TV form factor in the console, add TV
  screenshots (1920×1080) and a TV banner to the listing, pass the TV review.
- The Wear OS bundle merges the same manifest; check that the launcher
  category and banner do no harm there.

## Fire TV on Fire OS

Fire OS 7 and 8 are Android 9 and 11 underneath. The Android TV build runs
there unchanged; nothing in the game needs Google Play Services (Supabase
and Realtime are plain HTTPS and WebSockets), only the QR scanner uses
Google ML Kit, and televisions have no camera, so it never shows.

Open:

- Account in the Amazon Developer Console (free), upload the same APK or
  App Bundle, mark it for Fire TV, TV screenshots and a 1280×720 icon.
- Try on a Fire TV Stick with `adb` (developer options on, then
  `adb connect <ip>` and `flutter run -d <ip>:5555`). Amazon has been hiding
  the developer options on newer Fire OS updates; on some sticks they come
  back after tapping "About → Fire TV Stick" seven times.
- The Fire TV remote has play/pause and menu, so items and special weapons
  work as described above.

## Fire TV on Vega OS

Amazon's own Linux-based system, on the Fire TV Stick 4K Select since
October 2025 and the Fire TV Stick HD of 2026. Findings (October 2026):

- **Not the better sticks.** Vega is on the entry models. The 4K Max, the
  4K Plus, the Cube and televisions with Fire TV built in still run Fire OS
  and are covered by the Android build above.
- **No Android apps, no sideloading, no Flutter.** Apps are built with the
  Vega Developer Tools (once called Kepler) in React Native for Vega, or as
  a web app in the Vega WebView, packaged as `.vpkg` and installed only from
  the Amazon Appstore. A port of the game to React Native is out of the
  question.
- **The web build could work.** The game already runs in the browser at
  `/wargame/play/`. A thin Vega app around a WebView that loads it, with the
  television screens switched on (a `?tv=1` parameter, since `onTv` is off
  in the browser today), would keep one code base.
- **Unknowns for that shell:** whether Flutter web with CanvasKit and Flame
  keeps a steady frame rate in the WebView of an entry stick, whether the
  d-pad of the remote arrives as key events, and whether the Gamepad API
  (`lib/src/tv/web_pads.dart`) is there for controllers.

Next step, after Android TV: a half-day spike with the Vega Virtual Device
on the Mac (Vega Developer Tools need macOS or Linux), a WebView app loading
the web build, measuring frame rate and checking remote and controller.
Amazon requires a test on a real stick before the Appstore takes it.

Sources: [Getting started with Vega OS (Amazon, 2026)](https://developer.amazon.com/apps-and-games/blogs/2026/07/guide-to-building-for-fire-tv-on-vega-os),
[Announcing Vega Developer Tools](https://developer.amazon.com/apps-and-games/blogs/2025/09/announcing-vega-os),
[Run apps on the Vega Virtual Device](https://developer.amazon.com/docs/vega/0.23/run-apps),
[Powering Vega OS with React Native](https://swmansion.com/blog/amazon-x-software-mansion-powering-vega-os-with-react-native-75c4cf522fd7/).

## Trying it

```sh
# Android TV emulator: create a "Television (1080p)" device with a Google TV
# image in Android Studio's Device Manager, start it, then
flutter run -d emulator-5554

# Fire TV Stick on the same network, developer options and ADB debugging on
adb connect <ip-of-the-stick>
flutter run -d <ip-of-the-stick>:5555

# Rebuild the banner (and the Apple TV icons) after the app icon changed
python3 store/tool/tv_icons.py
```

In the emulator the arrow keys of the computer are the d-pad, Enter is OK,
Escape is Back.
