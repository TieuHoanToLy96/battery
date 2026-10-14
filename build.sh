#!/bin/bash
# Build Battery.app bundle từ Swift Package.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Battery"
BUNDLE_ID="com.local.batterymenubar"
BIN_NAME="battery"
BUILD_DIR=".build/release"
APP_DIR="$APP_NAME.app"

echo "==> swift build -c release"
swift build -c release

echo "==> Tạo bundle $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/$BIN_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"

if [ -f AppIcon.icns ]; then
    cp AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <!-- Menu bar app: không hiện trên Dock -->
    <key>LSUIElement</key>
    <true/>
    <!-- Bắt buộc để dùng IOBluetooth/CoreBluetooth (đọc pin khi kết nối) -->
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>Ứng dụng đọc mức pin của thiết bị Bluetooth đang kết nối để hiển thị và cảnh báo pin thấp.</string>
    <!-- Điều khiển Chrome để phát video đã chọn trong tab đang mở -->
    <key>NSAppleEventsUsageDescription</key>
    <string>Ứng dụng điều khiển trình duyệt để phát video bạn chọn trong tab đang mở.</string>
</dict>
</plist>
PLIST

echo "==> Ký ad-hoc (để UserNotifications hoạt động)"
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || echo "   (bỏ qua codesign)"

echo ""
echo "Xong: $APP_DIR"
echo "Chạy:  open $APP_DIR"
echo "Tắt:   nhấn icon menu bar -> Thoát"
