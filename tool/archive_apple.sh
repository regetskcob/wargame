#!/bin/bash
# Builds the App Store archive of the Apple TV or the Mac app and puts it
# where the Xcode Organizer lists it, named after platform, version and build.
# The tvOS and macOS counterpart of tool/archive_ios.sh, with the same defines
# and the same checks; signing comes from apple/Signing.xcconfig.
#
# Usage: tool/release.sh tvos|macos [--upload]   (on an up to date main;
# tool/release.sh calls this script)
#
# --upload sends the checked archive to App Store Connect
# (werkbank upload-apple); without it, upload it from the Organizer
# (Distribute App) or not at all. The tvOS engine has
# to carry an Apple Distribution signature for the App Store (ITMS-91065):
# flutter-tvos signs it when that certificate is in the keychain and warns
# otherwise.

set -euo pipefail

usage() { printf 'usage: %s tvos|macos [--upload]\n' "$0" >&2; exit 2; }
platform="${1:-}"
case "$platform" in
  tvos | macos) ;;
  *) usage ;;
esac
upload=0
case "${2:-}" in
  "") ;;
  --upload) upload=1 ;;
  *) usage ;;
esac

# Version from the werkbank (tool/werkbank/STANDARD.md).
cd "$(dirname "$0")/.."
# shellcheck source=tool/werkbank/lib/common.sh
. tool/werkbank/lib/common.sh
wb_enter_repo
wb_load_conf

name=$(wb_version name)
number=$(wb_version build)
# shellcheck source=tool/release_env.sh
. tool/release_env.sh
defines=("${release_defines[@]}")

step() { printf '\n== %s\n' "$*"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

archive="build/$platform/archive/Panzergefecht.xcarchive"
rm -rf "build/$platform/archive"

if [ "$platform" = "tvos" ]; then
  flutter_tvos="${FLUTTER_TVOS:-$HOME/flutter/flutter-tvos/bin/flutter-tvos}"
  step "Apple TV build $name ($number)"
  # Stages the engine, App.framework and the plugins; the archive signs.
  "$flutter_tvos" build tvos --release --no-codesign "${defines[@]}"
  destination='generic/platform=tvOS'
  app="$archive/Products/Applications/Runner.app"
  info="$app/Info.plist"
  dart="$app/Frameworks/App.framework/App"
else
  step "Mac build $name ($number)"
  # Writes the Flutter settings (defines, version) the archive builds with.
  flutter build macos --release "${defines[@]}"
  destination='generic/platform=macOS'
  app="$archive/Products/Applications/Panzergefecht.app"
  info="$app/Contents/Info.plist"
  dart="$app/Contents/Frameworks/App.framework/App"
fi

step "$platform archive $name ($number)"
(cd "$platform" && xcodebuild -workspace Runner.xcworkspace -scheme Runner \
  -configuration Release -destination "$destination" \
  -archivePath "../$archive" -allowProvisioningUpdates -quiet archive)

step "checks"
plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$2"; }
[ "$(plist CFBundleShortVersionString "$info")" = "$name" ] || fail "$app is not version $name"
[ "$(plist CFBundleVersion "$info")" = "$number" ] || fail "$app is not build $number"
[ "$(strings "$dart" | release_url_count)" -gt 0 ] ||
  fail "$app does not carry $release_supabase_url as a plain string"
codesign --verify --deep --strict "$app" || fail "the archived app has a broken signature"
team=$(codesign -dv "$app" 2>&1 | sed -n 's/^TeamIdentifier=//p')
# The Apple TV project carries its own team (flutter-tvos reads it from the
# project.pbxproj); a fork that changed only apple/Signing.xcconfig ends here.
[ "$team" = "$release_team" ] || fail "the archived app is signed for team '$team', not '$release_team'"
if [ "$platform" = "tvos" ]; then
  # Without them the upload warns "Upload Symbols Failed" (tool/make_dsym.sh).
  for dsym in App.framework Flutter.framework; do
    [ -d "$archive/dSYMs/$dsym.dSYM" ] || fail "the archive has no $dsym.dSYM"
  done
fi
echo "versions, Supabase URL, signature (team $team), dSYMs: ok"

target="$HOME/Library/Developer/Xcode/Archives/$(date +%F)/Panzergefecht $platform $name ($number) $(date +%H.%M.%S).xcarchive"
mkdir -p "$(dirname "$target")"
ditto "$archive" "$target"
echo "$target"
# Opening the archive hands it to Xcode, which lists it in the Organizer at
# once; an Organizer already open does not always notice a new folder.
[ -n "${CI:-}" ] || open "$target"
if [ "$upload" = "0" ]; then
  step "done"
  echo "Upload it with --upload, or in Xcode: Window > Organizer > Archives > Panzergefecht > Distribute App."
  exit 0
fi

wb_resolved_guard
step "upload $platform $name ($number) to App Store Connect"
wb_upload_apple "$target"
step "done"
echo "Uploaded. App Store Connect lists it under TestFlight once processed."
