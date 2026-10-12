#!/bin/bash
# Makes a dSYM for a binary that reaches an archive without one, so the
# App Store upload stops warning "Upload Symbols Failed" and crash reports
# name the functions. Called while archiving by the tvOS project (App.framework
# and the flutter-tvos engine) and by tool/embed_watch_app.sh (the
# flutter-watchos App.framework and engine); neither fork ships dSYMs.
#
# The engines carry a debug map pointing at object files on the machine that
# built them, and dsymutil gives up when it cannot open them. A copy without
# that map (strip -S keeps the symbol table and the UUID) gives a dSYM with the
# binary's UUID and its symbol table: function names, no line numbers. Dart
# frames need --split-debug-info either way.
#
# Usage: make_dsym.sh <binary> <output.dSYM>. Never fails the build: without
# a dSYM the upload only warns.

set -u

bin="$1"
out="$2"

uuids() { dwarfdump --uuid "$1" 2>/dev/null | awk '{print $2}' | sort; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
copy="$work/$(basename "$bin")"
rm -rf "$out"
if cp "$bin" "$copy" && strip -S "$copy" 2>/dev/null &&
  dsymutil "$copy" -o "$out" 2>/dev/null &&
  [ -n "$(uuids "$bin")" ] && [ "$(uuids "$bin")" = "$(uuids "$out")" ]; then
  echo "dSYM for $bin: $out"
else
  rm -rf "$out"
  echo "warning: no dSYM for $bin, the upload will warn about it"
fi
exit 0
