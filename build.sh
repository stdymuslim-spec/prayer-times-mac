#!/bin/bash
# Builds "Prayer Times.app", installs it to ~/Applications and launches it.
# No Apple Developer account needed: the app is ad-hoc signed, which is enough to run on this Mac.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Prayer Times.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -swift-version 5 -target "$(uname -m)-apple-macosx14.0" Sources/*.swift -o "$APP/Contents/MacOS/PrayerTimes"
cp Info.plist "$APP/Contents/"
cp Resources/timetable.json "$APP/Contents/Resources/"
# Sounds are optional: without them the app uses built-in macOS sounds.
for sound in reminder call_to_prayer; do
  if [ -f "Resources/$sound.mp3" ]; then cp "Resources/$sound.mp3" "$APP/Contents/Resources/"; fi
done

swiftc -O tools/make_icon.swift -o build/make_icon
build/make_icon build/icon-1024.png
ICONSET=build/AppIcon.iconset
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s build/icon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) build/icon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP"

pkill -x PrayerTimes || true
while pgrep -x PrayerTimes >/dev/null; do sleep 0.2; done
mkdir -p ~/Applications
rm -rf ~/Applications/"Prayer Times.app"
cp -R "$APP" ~/Applications/
open ~/Applications/"Prayer Times.app"
echo "Installed ~/Applications/Prayer Times.app"
