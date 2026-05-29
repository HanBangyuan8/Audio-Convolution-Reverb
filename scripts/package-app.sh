#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="Audio Convolution Reverb"
BUNDLE_ID="com.hanbangyuan.audio-convolution-reverb"
VERSION="1.1.0"
DIST_DIR="$ROOT_DIR/dist"
STAGE_DIR="${TMPDIR:-/tmp}/audio-convolution-reverb-package"
APP_DIR="$STAGE_DIR/$APP_NAME.app"
DMG_ROOT="$STAGE_DIR/dmg-root"
FINAL_APP_DIR="$DIST_DIR/$APP_NAME.app"
ICON_SOURCE="$ROOT_DIR/Resources/AppIcon.icns"

clean_bundle_metadata() {
  local bundle_dir="$1"
  find "$bundle_dir" -name "._*" -delete
  if command -v dot_clean >/dev/null 2>&1; then
    dot_clean -m "$bundle_dir"
  fi
  if command -v xattr >/dev/null 2>&1; then
    xattr -cr "$bundle_dir" 2>/dev/null || true
    while IFS= read -r -d '' file_path; do
      xattr -d com.apple.FinderInfo "$file_path" 2>/dev/null || true
      xattr -d 'com.apple.fileprovider.fpfs#P' "$file_path" 2>/dev/null || true
    done < <(find "$bundle_dir" -print0)
  fi
}

rm -rf "$APP_DIR" "$FINAL_APP_DIR" "$STAGE_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
mkdir -p "$DIST_DIR"

swift build -c release --arch arm64 --arch x86_64
BIN_PATH="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

cp "$BIN_PATH/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$BIN_PATH/audio-reverb-swift" "$DIST_DIR/audio-reverb-swift"
if [[ -f "$ICON_SOURCE" ]]; then
  cp "$ICON_SOURCE" "$APP_DIR/Contents/Resources/AppIcon.icns"
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
clean_bundle_metadata "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR"
clean_bundle_metadata "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

ditto --norsrc -c -k --keepParent "$APP_DIR" "$DIST_DIR/Audio-Convolution-Reverb-v${VERSION}-macOS-universal.zip"
mkdir -p "$DMG_ROOT"
ditto --norsrc "$APP_DIR" "$DMG_ROOT/$APP_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"
clean_bundle_metadata "$DMG_ROOT"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DIST_DIR/Audio-Convolution-Reverb-v${VERSION}.dmg"
ditto --norsrc "$APP_DIR" "$FINAL_APP_DIR"
clean_bundle_metadata "$FINAL_APP_DIR"
for attempt in 1 2 3; do
  if codesign --verify --deep --strict --verbose=2 "$FINAL_APP_DIR"; then
    break
  fi
  sleep 1
  clean_bundle_metadata "$FINAL_APP_DIR"
  if [[ "$attempt" == "3" ]]; then
    codesign --verify --deep --strict --verbose=2 "$FINAL_APP_DIR"
  fi
done

echo "Packaged:"
ls -lh "$DIST_DIR"
