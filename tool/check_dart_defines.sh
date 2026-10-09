#!/bin/sh
# Fails an Xcode build whose --dart-define values are malformed.
#
# Xcode takes the defines from ios/Flutter/Generated.xcconfig, which the last
# `flutter build`/`flutter run` in that checkout wrote. Build 4 was archived
# after a command that put all defines into one quoted value, so SUPABASE_URL
# read "https://… --dart-define=SUPABASE_KEY=…" and the app reached no server.
# Nothing between that command and the Organizer looked at the values.
#
# Usage: check_dart_defines.sh [base64,base64,…]  (default: $DART_DEFINES)

defines="${1:-$DART_DEFINES}"
status=0

fail() {
  # Xcode shows "error:" lines in the issue navigator.
  echo "error: $1" >&2
  status=1
}

old_ifs="$IFS"
IFS=','
for encoded in $defines; do
  IFS="$old_ifs"
  pair=$(printf '%s' "$encoded" | base64 -D 2>/dev/null || printf '%s' "$encoded" | base64 -d 2>/dev/null)
  name="${pair%%=*}"
  value="${pair#*=}"
  case "$value" in
    *--dart-define*) fail "dart-define $name swallowed further defines: '$value'. Quote each --dart-define on its own and run the flutter command again." ;;
  esac
  case "$value" in
    *[[:space:]]*) fail "dart-define $name contains whitespace: '$value'" ;;
  esac
  if [ "$name" = "SUPABASE_URL" ]; then
    case "$value" in
      https://*.*|http://localhost*|http://127.0.0.1*) ;;
      *) fail "SUPABASE_URL is no address: '$value'" ;;
    esac
    if [ "$CONFIGURATION" = "Release" ]; then
      case "$value" in
        https://*) ;;
        *) fail "a Release build must talk to an https SUPABASE_URL, not '$value'" ;;
      esac
    fi
  fi
  IFS=','
done
IFS="$old_ifs"

exit $status
