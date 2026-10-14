#!/bin/bash
# Cài Battery.app vào /Applications và cho tự chạy khi đăng nhập.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Battery"
LABEL="com.local.batterymenubar"
DEST="/Applications/$APP_NAME.app"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
BINARY="$DEST/Contents/MacOS/$APP_NAME"

# 1. Luôn build lại bundle để lấy code mới nhất.
echo "==> Build bundle (release)"
./build.sh

# 2. Dừng bản đang chạy (nếu có) rồi copy vào /Applications.
echo "==> Dừng bản đang chạy"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 1

echo "==> Cài vào $DEST"
rm -rf "$DEST"
cp -R "$APP_NAME.app" "$DEST"

# 3. Tạo LaunchAgent tự chạy khi login.
echo "==> Tạo LaunchAgent $AGENT"
mkdir -p "$(dirname "$AGENT")"
cat > "$AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BINARY</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>LimitLoadToSessionType</key>
    <string>Aqua</string>
</dict>
</plist>
PLIST

# 4. Load agent (chạy ngay + mỗi lần login).
echo "==> Load agent"
launchctl bootstrap "gui/$(id -u)" "$AGENT" 2>/dev/null \
    || launchctl load -w "$AGENT"

sleep 2
if pgrep -x "$APP_NAME" >/dev/null; then
    echo ""
    echo "✅ Đã cài & chạy. Icon pin ở menu bar."
    echo "   Tự khởi động khi đăng nhập: BẬT"
    echo "   Gỡ: ./uninstall.sh"
else
    echo "⚠️  Đã cài nhưng chưa thấy process — thử: open $DEST"
fi
