#!/bin/bash
# Builds the App Store archive of the iOS app with the watch app inside and
# puts it where the Xcode Organizer lists it, named after version and build.
#
# Build 5 reached TestFlight without the watch app: an archive made before
# the watch build was copied into the Organizer under a bare name next to a
# second, complete one, and the wrong one was uploaded. This script builds in
# the one order that works and refuses to hand over an archive it has not
# checked.
#
# Usage: tool/archive_ios.sh [--upload]   (from the repository root, on an
# up to date main)
#
# --upload also sends the checked archive to App Store Connect
# (tool/upload_archive.sh). Without the flag nothing leaves the machine.

set -euo pipefail

upload=0
for arg in "$@"; do
  case "$arg" in
    --upload) upload=1 ;;
    *) printf 'usage: %s [--upload]\n' "$0" >&2; exit 2 ;;
  esac
done

cd "$(dirname "$0")/.."

flutter_watchos="${FLUTTER_WATCHOS:-$HOME/flutter/flutter-watchos/bin/flutter-watchos}"
version=$(sed -n 's/^version: *//p' pubspec.yaml)
name="${version%%+*}"
number="${version##*+}"
defines=(--dart-define=ACCOUNTS=true)

step() { printf '\n== %s\n' "$*"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

step "watch app $name ($number)"
rm -rf build/watchos
"$flutter_watchos" build watchos --release "${defines[@]}"

step "iOS archive $name ($number)"
rm -rf build/ios/archive
flutter build ipa --release "${defines[@]}"

archive=build/ios/archive/Panzergefecht.xcarchive
app="$archive/Products/Applications/Panzergefecht.app"
watch="$app/Watch/Runner.app"

step "checks"
plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$2"; }
[ -d "$watch" ] || fail "the archive has no watch app at $watch"
for bundle in "$app" "$watch"; do
  [ "$(plist CFBundleShortVersionString "$bundle/Info.plist")" = "$name" ] || fail "$bundle is not version $name"
  [ "$(plist CFBundleVersion "$bundle/Info.plist")" = "$number" ] || fail "$bundle is not build $number"
  # Env falls back to the live project; a glued define would show here.
  # grep -c reads everything: grep -q would quit early and, with pipefail,
  # turn the SIGPIPE of strings into a failure.
  [ "$(strings "$bundle/Frameworks/App.framework/App" | grep -c 'https://[a-z0-9]*\.supabase\.co$')" -gt 0 ] ||
    fail "$bundle carries no plain Supabase URL"
done
[ "$(plist WKCompanionAppBundleIdentifier "$watch/Info.plist")" = "$(plist CFBundleIdentifier "$app/Info.plist")" ] ||
  fail "the watch app names another companion app"
[[ " $(lipo -archs "$watch/Runner") " == *" arm64_32 "* ]] || fail "the watch executable has no arm64_32 slice"
codesign --verify --deep --strict "$app" || fail "the archived app has a broken signature"
# Without them the upload warns "Upload Symbols Failed" (tool/make_dsym.sh).
for dsym in "Watch Runner.app" "Watch App.framework" "Watch Flutter.framework"; do
  [ -d "$archive/dSYMs/$dsym.dSYM" ] || fail "the archive has no $dsym.dSYM"
done
echo "watch app, versions, Supabase URL, signature, dSYMs: ok"

target="$HOME/Library/Developer/Xcode/Archives/$(date +%F)/Panzergefecht $name ($number) $(date +%H.%M.%S).xcarchive"
mkdir -p "$(dirname "$target")"
ditto "$archive" "$target"
echo "$target"
# Opening the archive hands it to Xcode, which lists it in the Organizer at
# once; an Organizer already open does not always notice a new folder.
[ -n "${CI:-}" ] || open "$target"

if [ "$upload" = "0" ]; then
  step "done"
  echo "Upload it with --upload, or in Xcode: Window > Organizer > Archives > Panzergefecht $name ($number) > Distribute App."
  exit 0
fi

step "upload $name ($number) to App Store Connect"
tool/upload_archive.sh "$target"
step "done"
echo "Uploaded. Once App Store Connect has processed it, TestFlight > build $number must say Apple Watch: yes."
