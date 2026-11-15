#!/bin/bash
# Packages build/Claude Assist.app into "Claude Assist.dmg" with an
# Applications shortcut for drag-to-install. Run ./build.sh first.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Claude Assist"
APP="build/${APP_NAME}.app"
DMG="${APP_NAME}.dmg"

[ -d "$APP" ] || { echo "Missing $APP — run ./build.sh first." >&2; exit 1; }

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/${APP_NAME}.app"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
echo "Built $DMG"
