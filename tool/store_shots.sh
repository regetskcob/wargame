#!/bin/sh
# Takes every raw picture for the store artwork without a hand on a
# simulator: one screenshot build per platform, then one launch per scene
# and language. The app walks into the scene itself and writes its own frame
# (Env.shotScene, lib/src/game/tank_game/shots.dart). The scene goes in as
# launch arguments, which land in the app's user defaults.
#
#   tool/release.sh shots <raw dir> [ios] [ipad] [tv] [mac]   (default: all)
#   tool/release.sh graphics <raw dir>         (tool/store/compose.py)
#
# Writes <raw dir>/<de-DE|en-US>/<name>.png with the names compose.py reads,
# and copies the Apple Watch frames from store/ios/watch/, which the watch
# app does not take itself.
# $defines splits on purpose; the build folders hold one app each.
# shellcheck disable=SC2086,SC2012
set -eu

raw="${1:?usage: tool/release.sh shots <raw dir> [ios] [ipad] [tv] [mac]}"
shift
targets="${*:-ios ipad tv mac}"
root="$(cd "$(dirname "$0")/.." && pwd)"
bundle=de.regetskcob.wargame
defines="--dart-define=ACCOUNTS=true --dart-define=SHOTS=true"
tvos_flutter="$HOME/flutter/flutter-tvos/bin"

# <raw name>:<scene> per device; PHONE_SCENES, TABLET_SCENES, TV_SCENES,
# MAC_SCENES and SHOT_LANGS (e.g. "en:en-US") retake only some.
phone_scenes="${PHONE_SCENES:-i_battle:battle i_defense:defense i_lobby:lobby i_menu:menu i_pad:pad}"
tablet_scenes="${TABLET_SCENES:-p_battle:battle p_defense:defense p_room:room}"
tv_scenes="${TV_SCENES:-tv_battle:battle tv_defense:defense}"
mac_scenes="${MAC_SCENES:-m_battle:battle m_defense:defense m_room:room}"

langs() { echo "${SHOT_LANGS:-de:de-DE en:en-US}"; }

# The id of the simulator named $1, created from device type $2 and the
# newest runtime of family $3 (iOS, tvOS) when missing, and booted.
simulator() {
  "$root/tool/werkbank/bin/werkbank" sim "$1" "$2" "$3"
}

# Waits up to $2 seconds for the file $1.
await_file() {
  i=0
  while [ ! -s "$1" ] && [ "$i" -lt "$2" ]; do
    sleep 1
    i=$((i + 1))
  done
  [ -s "$1" ]
}

# Shoots every scene of $2 on the simulator $1.
shoot_sim() {
  sim=$1
  tmp="$(xcrun simctl get_app_container "$sim" $bundle data)/tmp"
  mkdir -p "$tmp"
  for pair in $(langs); do
    for entry in $2; do
      out="$raw/${pair#*:}/${entry%%:*}.png"
      # A second try: the first launch after installing can take long.
      for _ in 1 2; do
        rm -f "$tmp/shot.png"
        xcrun simctl launch --terminate-running-process "$sim" $bundle \
          -ignoreGamepads YES -SHOT_SCENE "${entry#*:}" \
          -SHOT_LANG "${pair%%:*}" -SHOT_OUT "$tmp/shot.png" >/dev/null
        ! await_file "$tmp/shot.png" 60 || break
      done
      if [ -s "$tmp/shot.png" ]; then
        mkdir -p "$(dirname "$out")"
        mv "$tmp/shot.png" "$out"
        echo "$out"
      else
        echo "no picture for $out" >&2
      fi
    done
  done
}

cd "$root"
case " $targets " in *" ios "* | *" ipad "*)
  flutter build ios --simulator --debug $defines
  ;;
esac
case " $targets " in *" ios "*)
  sim=$(simulator "Store iPhone 6.9" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max iOS)
  xcrun simctl install "$sim" build/ios/iphonesimulator/Panzergefecht.app
  shoot_sim "$sim" "$phone_scenes"
  ;;
esac
case " $targets " in *" ipad "*)
  sim=$(simulator "Store iPad 13" com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB iOS)
  xcrun simctl install "$sim" build/ios/iphonesimulator/Panzergefecht.app
  shoot_sim "$sim" "$tablet_scenes"
  ;;
esac
case " $targets " in *" tv "*)
  PATH="$tvos_flutter:$PATH" flutter-tvos build tvos --simulator --debug $defines
  sim=$(simulator "Store Apple TV" com.apple.CoreSimulator.SimDeviceType.Apple-TV-4K-3rd-generation-4K tvOS)
  xcrun simctl install "$sim" "$(ls -d build/tvos/*simulator*/*.app | head -1)"
  shoot_sim "$sim" "$tv_scenes"
  # flutter-tvos wrote the plugin registrant for tvOS; give iOS its own back.
  flutter pub get >/dev/null
  ;;
esac
case " $targets " in *" mac "*)
  # Sign ad hoc as CI does: a team-signed debug build with the associated
  # domain needs a profile that lists this very Mac, and the pictures need
  # neither. An ad hoc signature cannot carry the domain, so it comes out of
  # the entitlements for the build and goes back in afterwards.
  local_signing="$root/apple/Signing.local.xcconfig"
  entitlements="$root/macos/Runner/DebugProfile.entitlements"
  [ -e "$local_signing" ] && cp "$local_signing" "$local_signing.shots"
  cp "$entitlements" "$entitlements.shots"
  restore_mac() {
    if [ -e "$local_signing.shots" ]; then
      mv "$local_signing.shots" "$local_signing"
    else
      rm -f "$local_signing"
    fi
    mv "$entitlements.shots" "$entitlements"
  }
  trap restore_mac EXIT
  printf 'DEVELOPMENT_TEAM =\nCODE_SIGN_IDENTITY = -\n' >"$local_signing"
  /usr/libexec/PlistBuddy -c 'Delete :com.apple.developer.associated-domains' \
    "$entitlements"
  flutter build macos --debug $defines
  restore_mac
  trap - EXIT
  app="$root/$(ls -d build/macos/Build/Products/Debug/*.app | head -1)"
  exe="$app/Contents/MacOS/$(defaults read "$app/Contents/Info" CFBundleExecutable)"
  # The sandbox lets the app write into its own container only.
  tmp="$HOME/Library/Containers/$bundle/Data/tmp"
  for pair in $(langs); do
    for entry in $mac_scenes; do
      out="$raw/${pair#*:}/${entry%%:*}.png"
      mkdir -p "$tmp" "$(dirname "$out")"
      rm -f "$tmp/shot.png"
      "$exe" -SHOT_SCENE "${entry#*:}" -SHOT_LANG "${pair%%:*}" \
        -SHOT_OUT "$tmp/shot.png" >/dev/null 2>&1 &
      pid=$!
      if await_file "$tmp/shot.png" 60; then
        mv "$tmp/shot.png" "$out"
        echo "$out"
      else
        echo "no picture for $out" >&2
      fi
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    done
  done
  ;;
esac

for lang in de-DE en-US; do
  mkdir -p "$raw/$lang"
  cp "store/ios/watch/$lang/watch-03-gefecht.png" "$raw/$lang/w_battle.png"
done
