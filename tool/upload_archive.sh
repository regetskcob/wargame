#!/bin/bash
# Sends a checked App Store archive (iOS, Apple TV or Mac) to App Store
# Connect, the way the Organizer's "Distribute App" does: xcodebuild signs
# with the Apple account signed in to Xcode and may fetch the App Store
# profiles itself. Called by tool/archive_ios.sh and tool/archive_apple.sh
# with --upload; releases are built and uploaded on this Mac only, since a
# macOS runner minute costs ten Linux minutes of the GitHub plan.
#
# Usage: tool/upload_archive.sh <path.xcarchive>

set -euo pipefail

archive="${1:-}"
[ -d "$archive" ] || { printf 'usage: %s <path.xcarchive>\n' "$0" >&2; exit 2; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cat > "$work/ExportOptions.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>86HB5U6788</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST
export_archive() {
  xcodebuild -exportArchive -archivePath "$archive" \
    -exportOptionsPlist "$work/ExportOptions.plist" \
    -exportPath "$work/export" -allowProvisioningUpdates
}
# The first upload of 1.2.0 (6) broke off with "The network connection was
# lost" and went through on the second try. A rejected build (say, a build
# number already taken) fails the same way twice.
if ! export_archive; then
  echo "Upload failed, trying once more."
  export_archive || {
    printf 'error: the upload failed twice; the archive is in the Organizer\n' >&2
    exit 1
  }
fi
