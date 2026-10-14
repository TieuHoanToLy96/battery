#!/bin/bash
# Tạo AppIcon.icns từ icon vẽ bằng make-icon.swift.
set -euo pipefail
cd "$(dirname "$0")"

PNG=/tmp/icon-1024.png
ICONSET=/tmp/Battery.iconset

echo "==> Vẽ icon 1024"
swift make-icon.swift "$PNG"

echo "==> Tạo iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
for sz in 16 32 64 128 256 512 1024; do
    sips -z $sz $sz "$PNG" --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null
done
# bản @2x (dùng ảnh gấp đôi)
cp "$ICONSET/icon_32x32.png"   "$ICONSET/icon_16x16@2x.png"
cp "$ICONSET/icon_64x64.png"   "$ICONSET/icon_32x32@2x.png"
cp "$ICONSET/icon_256x256.png" "$ICONSET/icon_128x128@2x.png"
cp "$ICONSET/icon_512x512.png" "$ICONSET/icon_256x256@2x.png"
cp "$ICONSET/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png"
# bỏ 64 (không thuộc chuẩn iconset)
rm -f "$ICONSET/icon_64x64.png"

echo "==> iconutil → AppIcon.icns"
iconutil -c icns "$ICONSET" -o AppIcon.icns
echo "Xong: AppIcon.icns"
