#!/bin/bash
# Builds "Claude Assist.app" into ./build
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Claude Assist"
EXECUTABLE="ClaudeAssist"
APP_DIR="build/${APP_NAME}.app"

swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp ".build/release/${EXECUTABLE}" "$APP_DIR/Contents/MacOS/${EXECUTABLE}"
[ -f Icon/AppIcon.icns ] || Icon/make_icon.sh
cp Icon/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>com.sarath.ClaudeAssist</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleExecutable</key><string>${EXECUTABLE}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP_DIR" >/dev/null
echo "Built $APP_DIR"
