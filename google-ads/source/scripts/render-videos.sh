#!/usr/bin/env bash
# Renders the vertical and landscape ads into ../output/<version>/ and normalises loudness to -14 LUFS (social video
# standard) with a two-pass loudnorm, so the ad isn't quieter than the videos around it.
# Usage (from google-ads/source): bash scripts/render-videos.sh v1 [composition prefix] [file stem]
#   v4: bash scripts/render-videos.sh v4 Ad4 collagemagik-editor-ad
set -euo pipefail
VERSION="${1:-v1}"
PREFIX="${2:-Ad}"
STEM="${3:-collagemagik-trip-ad}"
OUT="../output/$VERSION"
mkdir -p "$OUT" out/raw

render() { # composition id, file name
  local id="$1" name="$2"
  # REUSE_RAW=1 skips re-rendering when out/raw already has this video (only re-runs the loudness pass)
  if [[ "${REUSE_RAW:-0}" != "1" || ! -f "out/raw/$name.mp4" ]]; then
    npx remotion render "$id" "out/raw/$name.mp4" --codec=h264 --crf=18 --audio-bitrate=320k --log=error
  fi
  # pass 1: measure
  local stats
  stats=$(npx remotion ffmpeg -hide_banner -nostats -i "out/raw/$name.mp4" -vn \
    -af loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json -f null - 2>&1 | sed -n '/^{/,/^}/p')
  val() { echo "$stats" | grep "\"$1\"" | sed -E 's/.*: "([^"]+)".*/\1/'; }
  # pass 2: apply (linear), video copied untouched
  npx remotion ffmpeg -hide_banner -v error -y -i "out/raw/$name.mp4" -c:v copy \
    -af "loudnorm=I=-14:TP=-1.5:LRA=11:measured_I=$(val input_i):measured_TP=$(val input_tp):measured_LRA=$(val input_lra):measured_thresh=$(val input_thresh):offset=$(val target_offset):linear=true,aresample=48000" \
    -c:a aac -b:a 256k -movflags +faststart "$OUT/$name.mp4"
  echo "$OUT/$name.mp4"
}

render "${PREFIX}Vertical" "$STEM-vertical-9x16-1080x1920"
render "${PREFIX}Landscape" "$STEM-landscape-16x9-1920x1080"
render "${PREFIX}Square" "$STEM-square-1x1-1080x1080"
