#!/bin/bash
# Builds the signed App Bundle for Google Play on this machine, checks it and,
# with --upload, sends it to a Play track through fastlane (android/fastlane).
# The Android counterpart of tool/archive_ios.sh: releases are built locally
# only, CI just validates (docs/development.md "CI minutes").
#
# Usage: tool/release_android.sh phone|wear [--upload <track>] [--metadata]
#                                [--completed]
#   (from the repository root, on an up to date main)
#
#   phone|wear   the phone and tablet bundle, or the Wear OS one for the
#                watch's own wear: tracks
#   --upload     internal, alpha, beta or production; without it nothing
#                leaves the machine
#   --metadata   upload the store texts, icon and screenshots too
#   --completed  release at once instead of as a draft (Play accepts only
#                drafts until the app was released once)
#
# Needs android/key.properties (upload key, see android/key.properties.example)
# and, for --upload, the service account key at
# android/play-service-account.json or PLAY_JSON_KEY. The versionCode is the
# build number from pubspec.yaml (plus 100000 for the watch), so raise it
# before every upload.

set -euo pipefail

usage() {
  printf 'usage: %s phone|wear [--upload <track>] [--metadata] [--completed]\n' "$0" >&2
  exit 2
}

form_factor="${1:-}"
case "$form_factor" in
  phone | wear) shift ;;
  *) usage ;;
esac
track=""
metadata=0
status=draft
while [ $# -gt 0 ]; do
  case "$1" in
    --upload)
      track="${2:-}"
      case "$track" in internal | alpha | beta | production) ;; *) usage ;; esac
      shift 2
      ;;
    --metadata) metadata=1; shift ;;
    --completed) status=completed; shift ;;
    *) usage ;;
  esac
done

cd "$(dirname "$0")/.."

version=$(sed -n 's/^version: *//p' pubspec.yaml)
name="${version%%+*}"
number="${version##*+}"
build_args=(--dart-define=ACCOUNTS=true)
[ "$form_factor" = "wear" ] && build_args+=(--android-project-arg=wear=true)

step() { printf '\n== %s\n' "$*"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

# Without it Gradle signs with the debug key, and Play refuses the bundle.
[ -f android/key.properties ] || fail "android/key.properties is missing, see android/key.properties.example"

step "$form_factor bundle $name ($number)"
flutter build appbundle --release "${build_args[@]}"
bundle=build/app/outputs/bundle/release/app-release.aab
[ -f "$bundle" ] || fail "no bundle at $bundle"

step "checks"
# /usr/bin/keytool on macOS is a stub that needs a system Java; Gradle runs
# on the one inside Android Studio.
keytool=""
for candidate in "${JAVA_HOME:+$JAVA_HOME/bin/keytool}" \
  "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" \
  "$(command -v keytool || true)"; do
  if [ -n "$candidate" ] && "$candidate" -help > /dev/null 2>&1; then
    keytool="$candidate"
    break
  fi
done
[ -n "$keytool" ] || fail "no working keytool, set JAVA_HOME to a JDK"
# English output whatever the system language ("Eigentümer:" otherwise).
signer=$("$keytool" -J-Duser.language=en -printcert -jarfile "$bundle" | sed -n 's/^Owner: //p' | head -1)
[ -n "$signer" ] || fail "the bundle is not signed"
[[ "$signer" != *"Android Debug"* ]] || fail "the bundle is signed with the debug key"
# Env falls back to the live project; a glued define would show here. grep -c
# reads everything, see tool/archive_ios.sh.
[ "$(unzip -p "$bundle" base/lib/arm64-v8a/libapp.so | strings | grep -c 'https://[a-z0-9]*\.supabase\.co$')" -gt 0 ] ||
  fail "the bundle carries no plain Supabase URL"
echo "signature ($signer), Supabase URL: ok"

target="build/release/panzergefecht-$form_factor-$name-$number.aab"
mkdir -p build/release
cp "$bundle" "$target"
echo "$target"

if [ -z "$track" ]; then
  step "done"
  echo "Upload it with --upload internal (or alpha, beta, production)."
  exit 0
fi

step "upload $form_factor $name ($number) to the $track track as $status"
key="${PLAY_JSON_KEY:-$PWD/android/play-service-account.json}"
[ -f "$key" ] || fail "no service account key at $key"
args=(deploy "form_factor:$form_factor" "track:$track" "release_status:$status")
[ "$metadata" = "1" ] && args+=(metadata:true)
(cd android && PLAY_JSON_KEY="$key" FASTLANE_SKIP_UPDATE_CHECK=1 \
  FASTLANE_OPT_OUT_USAGE=1 LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
  bundle exec fastlane "${args[@]}")
step "done"
echo "Uploaded. A draft still has to be released in the Play Console."
