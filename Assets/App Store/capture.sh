#!/bin/zsh
# Captures raw App Store screenshots into Raw/<device>/<language>/.
# Usage: ./capture.sh [languages...]   (defaults to en)
#        DEVICES=iPad ./capture.sh    (defaults to both iPhone and iPad)
#
# The app is launched in demo mode on each screen through the -ScreenshotScreen
# launch argument. Run compose.swift afterwards to frame the captures.
set -e

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h:h}
BUNDLE_ID=com.tsubuzaki.Symphony
DERIVED_DATA=/tmp/symphony-screenshots-dd
LANGUAGES=($@)
(( $# )) || LANGUAGES=(en)
SCREENS=(01-apps:apps 02-builds:builds)
typeset -A DEVICE_TYPES=(
  iPhone com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro-Max
  iPad com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB
)

# MARK: - Simulators

simulator() {
  local name="Symphony Screenshots $1" udid
  udid=$(xcrun simctl list devices available | grep "$name (" | head -1 | grep -oE '[0-9A-F-]{36}' || true)
  if [[ -z $udid ]]; then
    udid=$(xcrun simctl create "$name" $DEVICE_TYPES[$1] com.apple.CoreSimulator.SimRuntime.iOS-27-0)
  fi
  echo $udid
}

# The language is set on the whole simulator, which is restarted to pick it up.
# The preferences are edited while it is shut down: a `defaults write` through
# simctl spawn does not survive the restart.
boot() {
  local preferences=~/Library/Developer/CoreSimulator/Devices/$1/data/Library/Preferences/.GlobalPreferences.plist
  # The first boot is what creates the preferences.
  xcrun simctl boot $1 2>/dev/null || true
  xcrun simctl bootstatus $1 -b >/dev/null
  xcrun simctl shutdown $1
  plutil -replace AppleLanguages -json "[\"$2\"]" "$preferences"
  xcrun simctl boot $1
  xcrun simctl bootstatus $1 -b >/dev/null
  xcrun simctl ui $1 appearance dark
  xcrun simctl status_bar $1 override --time 9:41 \
    --batteryState discharging --batteryLevel 100 \
    --cellularMode active --cellularBars 4 --wifiBars 3 --operatorName ""
}

# MARK: - Build

xcodebuild build -project "$PROJECT_DIR/Symphony.xcodeproj" -scheme Symphony -configuration Debug \
  -destination "generic/platform=iOS Simulator" -derivedDataPath $DERIVED_DATA -quiet
APP=$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Symphony.app

# MARK: - Capture

# One language at a time on one device; the iPhone and iPad run side by side.
capture() {
  local device=$1 udid=$(simulator $1) language screen
  for language in $LANGUAGES; do
    raw_dir="$SCRIPT_DIR/Raw/$device/$language"
    mkdir -p "$raw_dir"
    boot $udid $language

    # A fresh install, so nothing is left over from a real account.
    xcrun simctl uninstall $udid $BUNDLE_ID 2>/dev/null || true
    xcrun simctl install $udid $APP

    for screen in $SCREENS; do
      xcrun simctl launch --terminate-running-process $udid $BUNDLE_ID \
        -ScreenshotScreen ${screen#*:} >/dev/null
      # Let the demo data load and the push finish animating in.
      sleep 4
      xcrun simctl io $udid screenshot "$raw_dir/${screen%%:*}.png" >/dev/null 2>&1
    done
    xcrun simctl terminate $udid $BUNDLE_ID
    echo "captured $device/$language"
  done
}

for device in ${=DEVICES:-iPhone iPad}; do
  capture $device &
done
wait
