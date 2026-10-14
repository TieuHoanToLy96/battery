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
- 📈 Bấm vào thẻ thiết bị để mở cửa sổ lịch sử pin, chọn 24 giờ hoặc 7 ngày.
  Biểu đồ tự cập nhật; ngắt đường khi không có mẫu trong hơn 10 phút.

## Yêu cầu

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

## Test

```bash
swift test
```

## Cách hoạt động

- Mỗi 60s chạy `system_profiler SPBluetoothDataType -json`, parse thiết bị
  kết nối + pin.
- Ghi mẫu `{thiết bị, thời điểm, %}` vào
  `~/Library/Application Support/BatteryMenuBar/history.json`, tự xóa mẫu
  cũ hơn 7 ngày.
- `UsageEstimator` tính tốc độ xả trung bình (%/giờ) trên các đoạn pin
  giảm liên tục (bỏ đoạn sạc và đoạn cách nhau > 10 phút), rồi suy ra thời
  gian còn lại tới ngưỡng.

Chi tiết thiết kế: `docs/superpowers/specs/2026-10-08-bluetooth-battery-menubar-design.md`.
