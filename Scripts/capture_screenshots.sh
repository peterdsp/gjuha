#!/usr/bin/env bash
# Produces the App Store screenshots, end to end.
#
#   bash Scripts/capture_screenshots.sh
#
# Creates a 6.9 inch simulator if one is not already there, drives the real UI
# through GjuhaUITests/ScreenshotCapture, and writes PNGs to
# AppStoreScreenshots/ at 1320 x 2868, which is the size App Store Connect
# requires for the 6.9 inch display.
#
# Everything captured is real app state reached by driving the app. Nothing is
# seeded, so a fresh run shows a fresh account: zeroes on the counters and an
# empty goal ring. That is accurate, and it is also a weak first screenshot. To
# show populated figures, play through a lesson on the simulator by hand before
# the capture, or capture on a device you have actually been using. Do not seed
# numbers: the whole app is built around not overstating progress.
set -euo pipefail

cd "$(dirname "$0")/.."

DEVICE_NAME="${DEVICE_NAME:-Gjuha-Shots-69}"
DEVICE_TYPE="${DEVICE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max}"
OUT="${OUT:-AppStoreScreenshots}"
RESULT="$(mktemp -d)/shots.xcresult"

udid="$(xcrun simctl list devices --json \
  | python3 -c "
import json, sys
name = '$DEVICE_NAME'
for runtime, devices in json.load(sys.stdin)['devices'].items():
    if 'iOS' not in runtime:
        continue
    for d in devices:
        if d['name'] == name and d.get('isAvailable'):
            print(d['udid'])
            raise SystemExit
")"

if [ -z "$udid" ]; then
  runtime="$(xcrun simctl list runtimes --json \
    | python3 -c "
import json, sys
ios = [r for r in json.load(sys.stdin)['runtimes'] if r.get('isAvailable') and 'iOS' in r['name']]
print(sorted(ios, key=lambda r: r['version'])[-1]['identifier'])
")"
  echo "creating $DEVICE_NAME on $runtime"
  udid="$(xcrun simctl create "$DEVICE_NAME" "$DEVICE_TYPE" "$runtime")"
fi

echo "capturing on $DEVICE_NAME ($udid)"
xcrun simctl boot "$udid" 2>/dev/null || true

# TEST_RUNNER_ prefixed variables reach the test runner process; a plain one
# stays with xcodebuild and the capture skips itself.
TEST_RUNNER_GJUHA_CAPTURE=1 xcodebuild test \
  -project Gjuha.xcodeproj \
  -scheme Gjuha \
  -destination "id=$udid" \
  -only-testing:GjuhaUITests/ScreenshotCapture \
  -skipMacroValidation \
  -resultBundlePath "$RESULT" \
  >/dev/null

# $OUT is overridable from the environment and is about to be recursively
# deleted, so refuse anything that is not a plain relative subdirectory.
# `OUT=. bash Scripts/capture_screenshots.sh` would otherwise delete the repo.
case "$OUT" in
  ""|"."|".."|/*|*..*)
    echo "refusing to delete OUT=\"$OUT\": set it to a relative subdirectory" >&2
    exit 1
    ;;
esac

rm -rf "$OUT"
mkdir -p "$OUT"
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$OUT" >/dev/null
python3 Scripts/rename_screenshots.py "$OUT"

echo
for f in "$OUT"/*.png; do
  printf '%s  ' "$(basename "$f")"
  sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/ {printf "%s ", $2}'
  echo
done
