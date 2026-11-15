#!/bin/bash
# Renders AppIcon.png and packs it into AppIcon.icns.
set -euo pipefail
cd "$(dirname "$0")"

swift make_icon.swift AppIcon.png

ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z $size $size AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z $double $double AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o AppIcon.icns
rm -rf "$(dirname "$ICONSET")"
echo "Wrote AppIcon.icns"
