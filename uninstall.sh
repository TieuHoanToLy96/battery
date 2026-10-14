#!/bin/bash
# Gỡ Battery.app và LaunchAgent.
set -euo pipefail

APP_NAME="Battery"
LABEL="com.local.batterymenubar"
DEST="/Applications/$APP_NAME.app"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"

echo "==> Dừng & gỡ agent"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || launchctl unload -w "$AGENT" 2>/dev/null || true
pkill -x "$APP_NAME" 2>/dev/null || true
rm -f "$AGENT"

echo "==> Xoá app"
rm -rf "$DEST"

echo "✅ Đã gỡ. (Lịch sử pin vẫn giữ ở ~/Library/Application Support/BatteryMenuBar)"
echo "   Muốn xoá luôn: rm -rf ~/Library/Application\\ Support/BatteryMenuBar"
