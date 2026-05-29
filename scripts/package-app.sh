#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="Audio Convolution Reverb"
BUNDLE_ID="com.hanbangyuan.audio-convolution-reverb"
VERSION="1.1.0"
DIST_DIR="$ROOT_DIR/dist"
STAGE_DIR="/tmp/audio-convolution-reverb-package"
APP_DIR="$STAGE_DIR/$APP_NAME.app"
FINAL_APP_DIR="$DIST_DIR/$APP_NAME.app"

rm -rf "$APP_DIR" "$FINAL_APP_DIR" "$STAGE_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
mkdir -p "$DIST_DIR"

swift build -c release --arch arm64 --arch x86_64
BIN_PATH="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

cp "$BIN_PATH/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$BIN_PATH/audio-reverb-swift" "$DIST_DIR/audio-reverb-swift"
if [[ -f "$ROOT_DIR/assets/AppIcon.icns" ]]; then
  cp "$ROOT_DIR/assets/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "APPL????" > "$APP_DIR/Contents/PkgInfo"
find "$APP_DIR" -exec xattr -c {} \; 2>/dev/null || true
codesign --force --deep --sign - "$APP_DIR"
find "$APP_DIR" -exec xattr -c {} \; 2>/dev/null || true
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

ditto -c -k --keepParent "$APP_DIR" "$DIST_DIR/Audio-Convolution-Reverb-v${VERSION}-macOS-universal.zip"
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_DIR" -ov -format UDZO "$DIST_DIR/Audio-Convolution-Reverb-v${VERSION}.dmg"
ditto "$APP_DIR" "$FINAL_APP_DIR"

echo "Packaged:"
ls -lh "$DIST_DIR"
