#!/bin/sh
# Films scenes of the game on an iOS simulator for Streuwerk's reels: a
# screenshot build (SHOTS) walks into each scene by itself, and with
# SHOT_DRIVE a CPU brain drives the own tank, so the clip shows a round
# that is played. Screenshot builds leave out blood, see infantry.dart.
#
#   tool/streuwerk/record_scenes.sh <out dir> [scene[:seconds] ...]
#
# Scenes are those of lib/src/game/tank_game/shots.dart (battle, defense,
# room, lobby, menu, pad); default "battle:20 defense:20 room:8 pad:8".
# Writes <out dir>/<scene>.mp4 (H.264, the simulator's full resolution).
# Runs each scene through `flutter run`: a debug build started by simctl
# alone stays black on current iOS simulators.
# SIMULATOR names the device (default "Store iPhone 6.9").
set -eu

out="${1:?usage: tool/streuwerk/record_scenes.sh <out dir> [scene[:seconds] ...]}"
shift
scenes="${*:-battle:20 defense:20 room:8 pad:8}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
name="${SIMULATOR:-Store iPhone 6.9}"
sim=$("$root/tool/werkbank/bin/werkbank" sim "$name" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max iOS)
mkdir -p "$out"
log="$(mktemp)"
cd "$root"

for entry in $scenes; do
  scene=${entry%%:*}
  seconds=${entry#*:}
  [ "$seconds" = "$entry" ] && seconds=15
  flutter run -d "$sim" --dart-define=ACCOUNTS=true --dart-define=SHOTS=true \
    --dart-define=SHOT_DRIVE=true --dart-define=SHOT_SCENE="$scene" \
    --dart-define=SHOT_LANG=de >"$log" 2>&1 &
  runner=$!
  i=0
  until grep -q "key commands" "$log" || [ "$i" -ge 300 ]; do
    sleep 1
    i=$((i + 1))
  done
  # The scene needs a few seconds to walk in and settle.
  sleep 8
  xcrun simctl io "$sim" recordVideo --codec=h264 --force "$out/$scene.mp4" \
    >/dev/null 2>&1 &
  recorder=$!
  sleep "$seconds"
  kill -INT "$recorder"
  wait "$recorder" || true
  kill "$runner" 2>/dev/null || true
  wait "$runner" 2>/dev/null || true
  echo "$out/$scene.mp4"
done
rm -f "$log"
