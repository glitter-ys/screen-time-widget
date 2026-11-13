#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/屏幕计时.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
BINARY="$MACOS/ScreenTimer"

if [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
  SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
elif [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk ]]; then
  SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk"
else
  SDK="$(xcrun --show-sdk-path)"
fi

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES" "$BUILD/module-cache" "$BUILD/AppIcon.iconset"

echo "Building native widget…"
swiftc \
  -swift-version 5 \
  -parse-as-library \
  -O \
  -whole-module-optimization \
  -sdk "$SDK" \
  -target arm64-apple-macosx15.0 \
  -module-cache-path "$BUILD/module-cache" \
  -framework AppKit \
  -framework SwiftUI \
  -framework Combine \
  -framework QuartzCore \
  -framework CoreGraphics \
  -o "$BINARY" \
  "$ROOT"/Sources/*.swift

cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
printf 'APPL????' > "$CONTENTS/PkgInfo"

echo "Rendering app icon…"
"$BINARY" --icon "$BUILD/app-icon-1024.png" >/dev/null

ICONSET="$BUILD/AppIcon.iconset"
sips -z 16 16 "$BUILD/app-icon-1024.png" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$BUILD/app-icon-1024.png" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$BUILD/app-icon-1024.png" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$BUILD/app-icon-1024.png" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$BUILD/app-icon-1024.png" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$BUILD/app-icon-1024.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$BUILD/app-icon-1024.png" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$BUILD/app-icon-1024.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$BUILD/app-icon-1024.png" --out "$ICONSET/icon_512x512.png" >/dev/null
cp "$BUILD/app-icon-1024.png" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"

codesign --force --deep --sign - --timestamp=none "$APP" >/dev/null

ditto -c -k --keepParent --norsrc --noextattr "$APP" "$BUILD/屏幕计时.zip"

echo
echo "App:  $APP"
echo "Zip:  $BUILD/屏幕计时.zip"
echo "Open: open \"$APP\""
