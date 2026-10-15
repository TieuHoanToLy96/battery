#!/bin/bash
# Build Battery.app rồi đóng gói thành dist/Battery.zip để commit lên repo
# (link tải trong README). Chạy lại script này mỗi khi ra bản mới.
set -euo pipefail

cd "$(dirname "$0")"

./build.sh

echo "==> Đóng gói dist/Battery.zip"
mkdir -p dist
rm -f dist/Battery.zip
ditto -c -k --keepParent Battery.app dist/Battery.zip

echo ""
echo "Xong: dist/Battery.zip ($(du -h dist/Battery.zip | cut -f1))"
echo "Commit & push để cập nhật link tải:"
echo "  git add dist/Battery.zip && git commit -m 'chore: update prebuilt Battery.zip' && git push"
