#!/usr/bin/env bash
# Recaptures the app screens used in the ads, filled with the real travel photos in public/travel/, into public/shots/.
# Needs: a booted iPhone 17 Pro Max simulator (1320x2868 screenshots) and a Debug build of the app:
#   xcodebuild -project ../../ios/CollageMagik/CollageMagik.xcodeproj -scheme CollageMagik \
#     -destination 'generic/platform=iOS Simulator' -derivedDataPath <dd> build CODE_SIGNING_ALLOWED=NO
# Usage (from google-ads/source): bash scripts/capture-app-screens.sh <path to CollageMagik.app> [device]
# The export screen (09-export.png) needs taps in the UI, so it is captured separately (see README).
set -euo pipefail
APP="$1"
DEV="${2:-iPhone 17 Pro Max}"
BUNDLE=com.axpo.collagemagik
T="$(pwd)/public/travel"
M="$(pwd)/assets-raw/app-media"
OUT="public/shots"
mkdir -p "$OUT"

xcrun simctl status_bar "$DEV" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi

shot() { # name, wait seconds, env assignments...
  local name="$1" wait="$2"; shift 2
  xcrun simctl terminate "$DEV" "$BUNDLE" 2>/dev/null || true
  xcrun simctl uninstall "$DEV" "$BUNDLE" 2>/dev/null || true
  xcrun simctl install "$DEV" "$APP"
  env SIMCTL_CHILD_CM_PRO=1 "$@" xcrun simctl launch "$DEV" "$BUNDLE" >/dev/null
  sleep "$wait"
  rm -f "$OUT/$name.png" # simctl will not overwrite an existing file
  xcrun simctl io "$DEV" screenshot --type=png "$OUT/$name.png" >/dev/null 2>&1
  echo "$OUT/$name.png"
}

GREECE="$T/santorini-sunset.jpg,$T/santorini-domes.jpg,$T/dinner-fira.jpg,$T/santorini-windmills.jpg,$T/balcony.jpg"
TROPICS="$T/palm-beach.jpg,$T/overwater.jpg,$T/turquoise.jpg,$T/dock.jpg"
MIX="$T/balloons.jpg,$T/aurora-reine.jpg,$T/alpine-lake.jpg,$T/desert-road.jpg,$T/golden-palms.jpg,$T/bali-temple.jpg"
ITALY_VIDEO="$T/positano.jpg,$M/clip-golden-wave.mp4,$M/clip-venice-canal.mp4,$T/pizza.jpg"
ITALY="$T/positano.jpg,$T/venice-rialto.jpg,$T/amalfi.jpg,$T/pizza.jpg"

shot 01-carousel 9 SIMCTL_CHILD_CM_MODE=carousel SIMCTL_CHILD_CM_AUTOLOAD="$GREECE"
shot 02-carousel-next 9 SIMCTL_CHILD_CM_MODE=carousel SIMCTL_CHILD_CM_AUTOLOAD="$GREECE" SIMCTL_CHILD_CM_OFFSET=1.1
shot 03-resize 8 SIMCTL_CHILD_CM_AUTOLOAD="$TROPICS" SIMCTL_CHILD_CM_TAB=layout SIMCTL_CHILD_CM_SIZES=0.6,0.4
shot 04-layout 9 SIMCTL_CHILD_CM_AUTOLOAD="$MIX" SIMCTL_CHILD_CM_TAB=layout
shot 05-timeline 11 SIMCTL_CHILD_CM_AUTOLOAD="$ITALY_VIDEO" SIMCTL_CHILD_CM_TAB=timeline
shot 06-choose-part 11 SIMCTL_CHILD_CM_AUTOLOAD="$ITALY_VIDEO" SIMCTL_CHILD_CM_SELECT=1 SIMCTL_CHILD_CM_PART=1
shot 07-captions 9 SIMCTL_CHILD_CM_AUTOLOAD="$ITALY" SIMCTL_CHILD_CM_CAPTIONS=1 SIMCTL_CHILD_CM_CAPTION_TITLE="Summer in Italy" SIMCTL_CHILD_CM_CAPTION_SELECT=0
