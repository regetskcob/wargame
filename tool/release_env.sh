#!/bin/bash
# What every release build shares, sourced by tool/archive_ios.sh,
# tool/archive_apple.sh and tool/release_android.sh after wb_enter_repo:
#
# - release_defines: the --dart-define flags. Accounts are always on; the
#   backend and room settings come from the environment under the names the
#   web build reads from the repository variables (.github/workflows/pages.yaml),
#   so a fork can build its apps with `SUPABASE_URL=… SUPABASE_KEY=…
#   tool/release.sh ios` instead of editing lib/src/app/env.dart.
# - release_supabase_url: the address the build must carry, for the check
#   that no define was glued into another (see Env.supabaseUrl).
# - release_team: the Apple team of apple/Signing.xcconfig, or of
#   apple/Signing.local.xcconfig where that sets one.

# The scripts that source this file use the variables.
# shellcheck disable=SC2034

# The loop variable has a name of its own: the scripts sourcing this file
# keep the version in $name, and the loop once left it at PURCHASES.
release_defines=(--dart-define=ACCOUNTS=true)
for release_define in SUPABASE_URL SUPABASE_KEY WEB_URL MAX_PILOTS REALTIME_BUDGET PURCHASES; do
  if [ -n "${!release_define:-}" ]; then
    release_defines+=("--dart-define=$release_define=${!release_define}")
  fi
done
unset release_define

release_supabase_url="${SUPABASE_URL:-$(sed -n "s/.*defaultSupabaseUrl = '\(.*\)';/\1/p" lib/src/app/env.dart)}"
[ -n "$release_supabase_url" ] || {
  printf 'error: no defaultSupabaseUrl in lib/src/app/env.dart\n' >&2
  exit 1
}

# How many lines of `strings` end in the address, read from stdin. awk
# reads everything: grep -q would quit early and, with pipefail, turn the
# SIGPIPE of strings into a failure.
release_url_count() {
  awk -v url="$release_supabase_url" \
    'substr($0, length($0) - length(url) + 1) == url { n++ } END { print n + 0 }'
}

signing=(apple/Signing.xcconfig)
[ -f apple/Signing.local.xcconfig ] && signing+=(apple/Signing.local.xcconfig)
release_team=$(sed -n 's/^DEVELOPMENT_TEAM *= *\([A-Z0-9]*\).*/\1/p' "${signing[@]}" | tail -n 1)
