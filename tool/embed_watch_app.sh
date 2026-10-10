#!/bin/bash
# Embeds the prebuilt watch app into the iOS app (Xcode phase "Embed Prebuilt
# watchOS App" of the iOS Runner) and stops an archive that would ship
# without it or with a stale one.
#
# The watch app is not a target of ios/Runner.xcodeproj: flutter-watchos
# builds it into build/watchos/<conf>/Runner.app and this phase copies it to
# Panzergefecht.app/Watch. Build 5 went to App Store Connect without a watch
# app because the archive was made before the watch build existed and the
# phase only printed a warning. A plain `flutter build ios` (CI, verify.sh)
# may still go without the watch; an archive (ACTION=install) may not, unless
# ALLOW_NO_WATCH=1 says so on purpose.

set -eu

if [ "$CONFIGURATION" = "Debug" ]; then
  watch_conf="Debug-watchsimulator"
else
  watch_conf="Release-watchos"
fi

src="${SRCROOT}/../build/watchos/${watch_conf}/Runner.app"
dst="${BUILT_PRODUCTS_DIR}/${CONTENTS_FOLDER_PATH}/Watch"
archiving=0
if [ "${ACTION:-build}" = "install" ] && [ "${ALLOW_NO_WATCH:-0}" != "1" ]; then
  archiving=1
fi

# Xcode reuses the product folder between builds, so an old watch app would
# survive a build that has none.
rm -rf "$dst"

if [ ! -d "$src" ]; then
  message="watchOS app not found at $src. Run flutter-watchos build watchos --release (device) or --simulator first."
  if [ "$archiving" = "1" ]; then
    echo "error: $message An archive without it has no watch app in TestFlight." >&2
    exit 1
  fi
  echo "warning: $message"
  exit 0
fi

plist() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$2" 2>/dev/null || true
}

watch_plist="$src/Info.plist"
watch_name=$(plist CFBundleShortVersionString "$watch_plist")
watch_number=$(plist CFBundleVersion "$watch_plist")
# App Store Connect refuses a watch app whose version differs from the iOS
# app's; a leftover watch build of the last release is the usual cause.
if [ "$archiving" = "1" ]; then
  if [ "$watch_name" != "${FLUTTER_BUILD_NAME:-}" ] || [ "$watch_number" != "${FLUTTER_BUILD_NUMBER:-}" ]; then
    echo "error: the watch app is $watch_name ($watch_number), the iOS app ${FLUTTER_BUILD_NAME:-?} (${FLUTTER_BUILD_NUMBER:-?}). Build the watch app again with flutter-watchos build watchos --release." >&2
    exit 1
  fi
  if [ ! -f "$src/Frameworks/App.framework/App" ]; then
    echo "error: $src has no AOT App.framework, it is no release build." >&2
    exit 1
  fi
fi

mkdir -p "$dst"
cp -R "$src" "$dst/"
echo "Embedded watchOS app $watch_name ($watch_number) from $src"
