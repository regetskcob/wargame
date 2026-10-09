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
# Usage: tool/archive_ios.sh   (from the repository root, on an up to date main)

set -euo pipefail

cd "$(dirname "$0")/.."

flutter_watchos="${FLUTTER_WATCHOS:-$HOME/development/flutter-watchos/bin/flutter-watchos}"
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
echo "watch app, versions, Supabase URL, signature: ok"

target="$HOME/Library/Developer/Xcode/Archives/$(date +%F)/Panzergefecht $name ($number) $(date +%H.%M.%S).xcarchive"
mkdir -p "$(dirname "$target")"
ditto "$archive" "$target"
step "done"
echo "$target"
echo "Upload it in Xcode: Window > Organizer > Archives > Panzergefecht $name ($number) > Distribute App."
