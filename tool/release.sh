#!/usr/bin/env bash
# The one entry for checks, release builds and store pictures of Panzergefecht
# (tool/werkbank/STANDARD.md, "Ablauf"). Shared steps run through the werkbank
# copy in tool/werkbank/, settings in tool/werkbank.conf; what only this
# project has (watch app, Apple TV, fastlane, store shots) stays in the
# scripts next to this one.
#
#   tool/release.sh verify [--quick]
#       before every push: layout, format, analyze, tests without the
#       supabase tag, coverage floor; without --quick also the web, landing
#       page, iOS, macOS, Android and Wear OS builds (unsigned)
#   tool/release.sh android phone|wear [--upload <track>] [--metadata] [--completed]
#       signed App Bundle to build/release/, with --upload to Google Play
#       (tool/release_android.sh)
#   tool/release.sh ios [--upload]
#       App Store archive with the watch app inside, to the Xcode Organizer,
#       with --upload to App Store Connect (tool/archive_ios.sh)
#   tool/release.sh tvos|macos [--upload]
#       the same for the Apple TV or the Mac app (tool/archive_apple.sh)
#   tool/release.sh upload <path.xcarchive>
#       send a checked archive to App Store Connect (tool/upload_archive.sh)
#   tool/release.sh shots <raw dir> [ios] [ipad] [tv] [mac]
#       raw store pictures from the simulators (tool/store_shots.sh)
#   tool/release.sh graphics <raw dir>
#       store images from the raw pictures (tool/store/compose.py)
#
# Nothing leaves the machine without --upload. Runs from any working
# directory.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
wb="$here/werkbank/bin/werkbank"
# The repository of this script, whatever the working directory.
cd "$here/.."
# shellcheck source=tool/werkbank/lib/common.sh
. tool/werkbank/lib/common.sh
wb_enter_repo
wb_load_conf

usage() { sed -n '2,28p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2; }

cmd="${1:-}"
[ $# -gt 0 ] && shift
case "$cmd" in
  verify)
    case "${1:-}" in
      "") "$wb" verify ;;
      --quick)
        "$wb" verify --quick
        # werkbank skips verify_extra with --quick; the floor belongs to
        # the quick check all the same, as in CI.
        coverage_floor
        say "Quick check green, coverage floor included"
        ;;
      *) usage ;;
    esac
    ;;
  android) exec tool/release_android.sh "$@" ;;
  ios) exec tool/archive_ios.sh "$@" ;;
  tvos | macos) exec tool/archive_apple.sh "$cmd" "$@" ;;
  upload) exec tool/upload_archive.sh "$@" ;;
  shots) exec tool/store_shots.sh "$@" ;;
  graphics) exec python3 tool/store/compose.py "$@" ;;
  *) usage ;;
esac
