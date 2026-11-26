#!/usr/bin/env bash
# Draws the product media for Streuwerk (streuwerk/media/) from the game's own
# painters: vehicles, crates, terrain cut-outs and base stages as PNGs with a
# transparent background, and a short clip per vehicle (turret sweep and a
# shot) on the template's dark olive. Needs ffmpeg.
set -euo pipefail
cd "$(dirname "$0")/../.."
frames=/tmp/streuwerk-frames
rm -rf "$frames" streuwerk/media/fahrzeuge streuwerk/media/kisten \
  streuwerk/media/gelaende streuwerk/media/karten streuwerk/media/stuetzpunkt streuwerk/media/clips
flutter test tool/streuwerk/render_media_test.dart --run-skipped --tags media
mkdir -p streuwerk/media/clips
for dir in "$frames"/*/; do
  name=$(basename "$dir")
  # H.264 has no alpha, so the clips sit on the template's background.
  ffmpeg -loglevel error -y -f lavfi -i "color=c=0x141A0E:s=720x720:r=30" \
    -framerate 30 -i "$dir/%03d.png" \
    -filter_complex "[0][1]overlay=shortest=1,format=yuv420p" \
    -c:v libx264 -crf 22 -movflags +faststart -an "streuwerk/media/clips/$name.mp4"
  ffmpeg -loglevel error -y -i "streuwerk/media/clips/$name.mp4" -frames:v 1 \
    "streuwerk/media/clips/$name.png"
done
rm -rf "$frames"
