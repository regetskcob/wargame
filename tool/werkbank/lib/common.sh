# Shared functions of the werkbank CLI. Sourced by bin/werkbank; a project's
# tool/release.sh may source it too (after wb_enter_repo / wb_load_conf the
# wb_* functions work there the same way).
# shellcheck shell=bash

say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# The repository root of the current directory, so every path below is
# relative to it.
wb_enter_repo() {
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git repository"
  cd "$root" || die "cannot enter $root"
}

# Defaults, then tool/werkbank.conf of the project. Everything in the conf is
# optional; see STANDARD.md, "werkbank.conf".
wb_load_conf() {
  WB_APP=""
  WB_TOP_EXTRA=""
  WB_MEDIA_EXTRA=""
  WB_FORMAT_PATHS="lib test"
  WB_TEST_ARGS=""
  WB_ANALYZE_ARGS=""
  WB_SYMBOLS_DIR=""
  if [ -f tool/werkbank.conf ]; then
    # shellcheck disable=SC1091
    . tool/werkbank.conf
  fi
  [ -n "$WB_APP" ] || WB_APP=$(sed -n 's/^name: *//p' pubspec.yaml 2>/dev/null | head -1)
  [ -n "$WB_APP" ] || WB_APP=$(basename "$PWD")
  [ -n "$WB_SYMBOLS_DIR" ] || WB_SYMBOLS_DIR="$HOME/keys/symbols/$WB_APP"
}

# Whether the project defined the hook function $1 in its conf.
wb_has_hook() { declare -F "$1" >/dev/null; }

# Sources an env file (secrets kept outside the repository, usually
# ~/.config/<app>/<name>.env) if it exists; returns 1 if it does not.
wb_env_file() {
  [ -f "$1" ] || return 1
  # shellcheck disable=SC1090
  . "$1"
}

# ---------------------------------------------------------------------------
# Folder structure

# Top-level entries every app repository may have (STANDARD.md, "Ordnerstruktur").
WB_TOP_BASE='\.claude|\.github|\.gitignore|\.gitattributes|\.metadata|\.vscode|CLAUDE\.md|README\.md|LICENSE|CHANGELOG(\.[a-z]{2})?\.md|analysis_options\.yaml|dart_test\.yaml|build\.yaml|l10n\.yaml|pubspec\.(yaml|lock)|android|ios|macos|linux|windows|web|lib|test|integration_test|test_driver|assets|docs|tool|store|site|supabase'
# Where images, PDFs, videos, models, archives and app binaries may live.
WB_MEDIA_BASE='(android|ios|macos|linux|windows|web|assets|store)/|site/(static|assets)/|docs/(images|pdf)/|(test|integration_test)/(.*/)?goldens/'
WB_MEDIA_EXT='png|jpe?g|gif|webp|heic|psd|pdf|mp4|mov|stl|step|3mf|zip|xz|aab|apk|ipa'

wb_layout() {
  local top_re="^(${WB_TOP_BASE}${WB_TOP_EXTRA:+|$WB_TOP_EXTRA})$"
  local media_re="^(${WB_MEDIA_BASE}${WB_MEDIA_EXTRA:+|$WB_MEDIA_EXTRA})"
  local top media
  top=$(git ls-files | cut -d/ -f1 | sort -u | grep -vE "$top_re" || true)
  media=$(git ls-files | grep -iE "\\.(${WB_MEDIA_EXT})\$" | grep -vE "$media_re" || true)
  [ -z "$top" ] || die "unknown top-level entries (STANDARD.md, Ordnerstruktur): $(tr '\n' ' ' <<<"$top")"
  [ -z "$media" ] || die "media outside their folders (STANDARD.md, Ordnerstruktur): $(tr '\n' ' ' <<<"$media")"
}

# ---------------------------------------------------------------------------
# Checks

# The checks of the pull request CI, run before every push. --quick skips the
# project's verify_extra (builds and other slow steps).
wb_verify() {
  local quick=false
  [ "${1:-}" = --quick ] && quick=true
  say "Layout"
  wb_layout
  say "Dependencies"
  flutter pub get >/dev/null
  if [ -f l10n.yaml ]; then
    say "Translations"
    flutter gen-l10n >/dev/null
    local dir
    dir=$(sed -n 's/^output-dir: *//p' l10n.yaml)
    [ -n "$dir" ] || dir=$(sed -n 's/^arb-dir: *//p' l10n.yaml)
    [ -n "$dir" ] || dir=lib/l10n
    git diff --exit-code --quiet -- "$dir" || die "$dir out of date – run flutter gen-l10n and commit"
  fi
  say "Format"
  # shellcheck disable=SC2086
  dart format --output=none --set-exit-if-changed $WB_FORMAT_PATHS >/dev/null ||
    die "unformatted files – run dart format $WB_FORMAT_PATHS"
  say "Analyze"
  # shellcheck disable=SC2086
  flutter analyze --no-pub $WB_ANALYZE_ARGS
  say "Tests"
  # shellcheck disable=SC2086
  flutter test --no-pub $WB_TEST_ARGS
  if $quick; then
    say "Quick check green"
    return 0
  fi
  if wb_has_hook verify_extra; then
    verify_extra
  fi
  say "All green"
}

# ---------------------------------------------------------------------------
# Version

wb_version() {
  local v
  v=$(sed -n 's/^version: *//p' pubspec.yaml | head -1)
  [ -n "$v" ] || die "no version in pubspec.yaml"
  case "${1:-}" in
    name) echo "${v%%+*}" ;;
    build) [[ "$v" == *+* ]] && echo "${v##*+}" || echo "" ;;
    "") echo "$v" ;;
    *) die "werkbank version [name|build]" ;;
  esac
}

# ---------------------------------------------------------------------------
# Release builds

# A keytool that really runs: /usr/bin/keytool on macOS is a stub that prints
# nothing without a system Java, so a signature check would always pass.
wb_keytool() {
  local candidate
  for candidate in "${JAVA_HOME:+$JAVA_HOME/bin/keytool}" \
    "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" \
    "$(command -v keytool || true)"; do
    if [ -n "$candidate" ] && "$candidate" -help >/dev/null 2>&1; then
      echo "$candidate"
      return 0
    fi
  done
  die "no working keytool – install Android Studio or set JAVA_HOME to a JDK"
}

# Fails unless the bundle or APK $1 is signed, and not with the debug key.
wb_check_signature() {
  local keytool signer
  keytool=$(wb_keytool)
  # English output whatever the system language ("Eigentümer:" otherwise).
  signer=$("$keytool" -J-Duser.language=en -printcert -jarfile "$1" 2>&1 | sed -n 's/^Owner: //p' | head -1)
  [ -n "$signer" ] || die "$1 is not signed"
  [[ "$signer" != *"Android Debug"* ]] || die "$1 is signed with the debug key – check android/key.properties"
}

# Copies build/symbols/<platform> (from --split-debug-info) to
# $WB_SYMBOLS_DIR/<version>/<platform>: build/ is wiped by flutter clean, the
# symbols are needed to read crash reports of exactly this build.
wb_symbols() {
  local platform=$1 target
  [ -d "build/symbols/$platform" ] || return 0
  target="$WB_SYMBOLS_DIR/$(wb_version)"
  mkdir -p "$target"
  rm -rf "${target:?}/$platform"
  cp -R "build/symbols/$platform" "$target/$platform"
  say "Debug symbols kept in $target/$platform"
}

# Release file name: build/release/<app>-<version>.<ext>
wb_release_path() { echo "build/release/$WB_APP-$(wb_version).$1"; }

# Signed App Bundle. Arguments after -- go to flutter build appbundle, after
# those of the project's android_args hook.
wb_android() {
  [ "${1:-}" = -- ] && shift
  [ -f android/key.properties ] || die "android/key.properties missing – without it Gradle signs with the debug key (STANDARD.md, Schlüssel)"
  local args=()
  if wb_has_hook android_args; then
    # shellcheck disable=SC2207
    args=($(android_args))
  fi
  say "App Bundle $(wb_version)"
  flutter build appbundle --release ${args[@]+"${args[@]}"} "$@"
  local aab=build/app/outputs/bundle/release/app-release.aab
  [ -f "$aab" ] || die "no bundle at $aab"
  wb_check_signature "$aab"
  wb_symbols android
  local out
  out=$(wb_release_path aab)
  mkdir -p build/release
  cp "$aab" "$out"
  say "Signed bundle: $out"
}

# IPA. --upload sends it to App Store Connect with an API key: ASC_KEY_ID,
# ASC_ISSUER_ID and the key file ASC_KEY_PATH (default
# ~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8).
wb_ios() {
  local upload=false
  if [ "${1:-}" = --upload ]; then upload=true; shift; fi
  [ "${1:-}" = -- ] && shift
  if $upload; then wb_asc_key >/dev/null; fi
  local args=()
  if wb_has_hook ios_args; then
    # shellcheck disable=SC2207
    args=($(ios_args))
  fi
  say "IPA $(wb_version)"
  rm -rf build/ios/ipa
  flutter build ipa --release ${args[@]+"${args[@]}"} "$@"
  local ipa
  ipa=$(find build/ios/ipa -maxdepth 1 -name '*.ipa' | head -1)
  [ -n "$ipa" ] || die "no IPA in build/ios/ipa"
  wb_symbols ios
  local out
  out=$(wb_release_path ipa)
  mkdir -p build/release
  cp "$ipa" "$out"
  say "IPA: $out"
  if $upload; then
    say "Uploading to App Store Connect"
    API_PRIVATE_KEYS_DIR=$(dirname "$(wb_asc_key)") \
      xcrun altool --upload-app --type ios -f "$out" --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
  else
    say "Not uploaded – werkbank ios --upload, Transporter, or Xcode (build/ios/archive/Runner.xcarchive → Distribute App)"
  fi
}

# Path of the App Store Connect API key; fails with what is missing.
wb_asc_key() {
  [ -n "${ASC_KEY_ID:-}" ] || die "ASC_KEY_ID missing (App Store Connect → Users and Access → Integrations → Keys)"
  [ -n "${ASC_ISSUER_ID:-}" ] || die "ASC_ISSUER_ID missing"
  local key="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8}"
  [ -f "$key" ] || die "API key $key missing"
  [ "$(basename "$key")" = "AuthKey_$ASC_KEY_ID.p8" ] || die "altool needs the key file named AuthKey_$ASC_KEY_ID.p8, not $(basename "$key")"
  echo "$key"
}

# ---------------------------------------------------------------------------
# Screenshots

# Finds the available simulator named $1 or creates it from device type $2
# with the newest runtime of family $3 (iOS, tvOS, watchOS), boots it and
# prints its UDID. Named simulators keep store shots on the same device.
wb_sim() {
  local name=${1:?name} type=${2:?device type} family=${3:-iOS} id runtime
  id=$(xcrun simctl list devices available | grep -F "    $name (" | head -1 |
    sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
  if [ -z "$id" ]; then
    runtime=$(xcrun simctl list runtimes available | grep "^$family " | tail -1 | awk '{print $NF}')
    [ -n "$runtime" ] || die "no $family runtime installed (Xcode → Settings → Components)"
    id=$(xcrun simctl create "$name" "$type" "$runtime")
  fi
  xcrun simctl bootstatus "$id" -b >/dev/null
  echo "$id"
}

# ---------------------------------------------------------------------------

wb_doctor() {
  local tool
  for tool in git flutter dart xcrun gh hugo python3 shellcheck; do
    if command -v "$tool" >/dev/null; then say "$tool: $(command -v "$tool")"; else warn "$tool missing"; fi
  done
  (wb_keytool >/dev/null) && say "keytool: $(wb_keytool)" || true
  if [ -f android/key.properties ]; then
    say "android/key.properties present"
  else
    warn "android/key.properties missing (needed for werkbank android)"
  fi
  if (wb_asc_key >/dev/null 2>&1); then
    say "App Store Connect API key present"
  else
    warn "no App Store Connect API key (needed for werkbank ios --upload)"
  fi
  say "app $WB_APP, version $(wb_version 2>/dev/null || echo '?'), symbols to $WB_SYMBOLS_DIR"
  [ -f tool/werkbank/VERSION ] && say "werkbank $(cat tool/werkbank/VERSION)"
  return 0
}
