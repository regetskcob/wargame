#!/usr/bin/env bash
# Runs what CI runs, plus the iOS and Android builds, so a push to main only
# happens when everything is green. `--quick` stops after the tests.
set -euo pipefail
cd "$(dirname "$0")/.."

quick=false
[ "${1:-}" = "--quick" ] && quick=true

step() { printf '\n==> %s\n' "$*"; }

step "dart format"
dart format --set-exit-if-changed .
step "flutter analyze"
flutter analyze
step "flutter test (without the supabase tag)"
flutter test --exclude-tags supabase

if $quick; then
  printf '\nQuick check green.\n'
  exit 0
fi

step "flutter build web"
flutter build web
step "flutter build ios --release --no-codesign"
flutter build ios --release --no-codesign
step "flutter build appbundle --release"
flutter build appbundle --release

printf '\nAll green: format, analyze, test, web, iOS, Android.\n'
