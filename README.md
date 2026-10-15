# Battery — Bluetooth Battery Menu Bar

App macOS native chạy trên menu bar, hiển thị các thiết bị Bluetooth đang
kết nối kèm % pin, cảnh báo khi pin thấp, và **ước lượng thời gian dùng
pin còn lại** dựa trên lịch sử sử dụng 7 ngày.

## Tính năng

- 🔋 Liệt kê thiết bị Bluetooth kết nối + % pin (gồm AirPods trái/phải/case).
- ⚠️ Cảnh báo khi pin < ngưỡng:
  - Notification hệ thống.
  - Icon menu bar chuyển **đỏ**.
  - Hiện tên thiết bị sắp hết pin ngay cạnh icon.
- ⏱️ Ước lượng "Còn ~Xh Ym đến {ngưỡng}%" từ tốc độ xả trung bình 7 ngày.
  Tự loại đoạn đang sạc và đoạn ngắt kết nối khỏi phép tính.
- ⚙️ Ngưỡng cảnh báo chỉnh được (10/15/20/25/30%), lưu lại.
- 🎵 Tìm & phát nhạc YouTube ngay trong popover:
  - Ô "Tìm trên YouTube…" tìm video không cần API key (parse trang kết quả).
  - Bấm kết quả để phát: thay URL tab YouTube đang mở trong Chrome (không
    kéo Chrome lên trước); nếu chưa có tab YouTube thì mở tab mới.
  - Điều khiển trình phát: bài trước/sau, lặp lại (loop), và EQ
    (Web Audio) áp trực tiếp lên video.

## Cài đặt (người dùng)

Không cần Xcode. Mở **Terminal**, dán đúng 1 dòng dưới đây rồi Enter — nó tự
tải, cài vào `/Applications` và mở app:

```bash
curl -fsSL -o /tmp/Battery.zip https://github.com/TieuHoanToLy96/battery/raw/main/dist/Battery.zip && rm -rf /Applications/Battery.app && ditto -x -k /tmp/Battery.zip /Applications && xattr -dr com.apple.quarantine /Applications/Battery.app && open /Applications/Battery.app
```

Xong là icon pin hiện trên menu bar.

> **Vì sao cần gỡ "quarantine"?** App chưa mua chứng chỉ Apple Developer để
> notarize, nên macOS mặc định chặn app tải từ mạng ("Battery is damaged" /
> "nhà phát triển không xác định"). Lệnh `xattr -dr com.apple.quarantine` ở
> trên gỡ cờ chặn đó. App vẫn được ký ad-hoc cục bộ, không chỉnh sửa gì thêm.

<details>
<summary>Cài thủ công (không dùng Terminal)</summary>

1. Tải [`dist/Battery.zip`](https://github.com/TieuHoanToLy96/battery/raw/main/dist/Battery.zip) và giải nén.
2. Kéo `Battery.app` vào thư mục **Applications**.
3. Lần đầu mở: **chuột phải vào app → Open → Open**.
4. Nếu macOS báo *"is damaged and can't be opened"* (hay gặp trên máy Apple
   Silicon), chạy trong Terminal: `xattr -dr com.apple.quarantine /Applications/Battery.app` rồi mở lại.
</details>

Muốn app **tự chạy khi đăng nhập**? Clone repo và chạy `./install.sh` (tạo
LaunchAgent), hoặc tự thêm Battery vào *System Settings → General → Login Items*.

## Yêu cầu (để tự build)

- macOS 13+
- Swift toolchain (Xcode hoặc Command Line Tools)

## Build & chạy

```bash
# Chạy nhanh khi dev
swift run battery

# Hoặc đóng gói thành Battery.app
./build.sh
open Battery.app
```

Icon pin sẽ xuất hiện trên menu bar. Nhấn vào để xem danh sách thiết bị,
chọn ngưỡng, làm mới, hoặc thoát.

> Lần đầu chạy, macOS có thể hỏi quyền gửi thông báo — hãy cho phép để nhận
> cảnh báo pin thấp.

## Điều khiển YouTube trên Chrome

Phát video (thay URL tab YouTube) chỉ cần quyền **Automation** điều khiển
Chrome. Nhưng các thao tác **bài trước/sau, lặp lại (loop) và EQ** chạy bằng
JavaScript qua Apple Events — mặc định Chrome **tắt** tính năng này, nên cần
bật thủ công một lần:

1. Mở **Google Chrome**.
2. Vào menu **View → Developer → Allow JavaScript from Apple Events**
   (bật dấu tích).
3. Lần đầu điều khiển, macOS sẽ hỏi cấp quyền **Automation** cho app điều
   khiển Chrome — chọn **OK**. (Có thể kiểm tra/bật lại tại
   *System Settings → Privacy & Security → Automation*.)

Nếu không bật, phát video vẫn chạy nhưng next/prev/loop/EQ sẽ không có tác
dụng.

## Test

```bash
swift test
```

## Cách hoạt động

- Mỗi 60s đọc thiết bị Bluetooth kết nối + pin qua `CompositeBatteryReader`
  gồm 3 nguồn theo thứ tự ưu tiên: `IOBluetoothFrameworkReader` →
  `IORegistryBatteryReader` → `BluetoothBatteryReader` (`system_profiler
  SPBluetoothDataType -json`, fallback cuối cho thiết bị bị các nguồn kia
  bỏ sót).
- Ghi mẫu `{thiết bị, thời điểm, %}` vào
  `~/Library/Application Support/BatteryMenuBar/history.json`, tự xóa mẫu
  cũ hơn 7 ngày.
- `UsageEstimator` tính tốc độ xả trung bình (%/giờ) trên các đoạn pin
  giảm liên tục (bỏ đoạn sạc và đoạn cách nhau > 10 phút), rồi suy ra thời
  gian còn lại tới ngưỡng.

Chi tiết thiết kế: `docs/superpowers/specs/2026-10-08-bluetooth-battery-menubar-design.md`.
