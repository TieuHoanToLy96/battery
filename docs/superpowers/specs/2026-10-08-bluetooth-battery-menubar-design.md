# Bluetooth Battery Menu Bar — Design

Date: 2026-10-08
Status: Approved (design)

## Mục tiêu

App macOS native (Swift) chạy trên menu bar, hiển thị các thiết bị
Bluetooth đang kết nối kèm % pin, cảnh báo khi pin dưới ngưỡng, và ước
lượng thời gian sử dụng pin còn lại dựa trên lịch sử 7 ngày.

## Yêu cầu

- Chỉ hiển thị thiết bị Bluetooth (không hiện pin của Mac).
- Cảnh báo khi pin < ngưỡng (mặc định 20%, chỉnh được):
  - Notification hệ thống (UserNotifications).
  - Đổi màu icon menu bar sang đỏ.
  - Hiện tên thiết bị sắp hết pin ngay cạnh icon.
- Ngưỡng cảnh báo chỉnh được qua menu, lưu lại (UserDefaults).
- Ước lượng "còn ~Xh Ym đến {ngưỡng}%" dựa trên tốc độ xả trung bình 7 ngày.

## Nguồn dữ liệu

**Chính: IORegistry** qua `ioreg -a -r -l -k BatteryPercent` (và
`BatteryPercentCombined`) — output plist, có `Product`, `DeviceAddress`,
`BatteryPercent` (và `BatteryPercentLeft/Right/Case` cho AirPods). Trên
thực tế nhiều thiết bị (bàn phím, chuột, trackpad, tai nghe) CHỈ expose pin
qua IORegistry chứ không qua system_profiler — phát hiện khi verify trên
máy thật (Magic Trackpad có pin ở IORegistry nhưng trống ở system_profiler).

**Phụ: `system_profiler SPBluetoothDataType -json`** — gộp bổ sung cho các
thiết bị/các mức pin mà IORegistry bỏ sót.

Hai nguồn được gộp qua `CompositeBatteryReader`, dedup theo địa chỉ đã
**chuẩn hoá** (bỏ dấu phân cách, lowercase — vì IORegistry dùng
`a0-78-...` còn system_profiler dùng `A0:78:...`). Poll mỗi 60s.

Charging state không nguồn nào expose tin cậy → suy ra từ chênh lệch %.

Charging state không được system_profiler expose tin cậy cho phụ kiện BT
→ **suy ra** từ chênh lệch %: nếu % tăng so với mẫu trước = đang sạc
(loại khỏi tính xả); giảm = đang xả.

## Kiến trúc

Hai target Swift Package:

- **Library `BatteryKit`** (logic thuần, test được):
  - `BluetoothDevice` — model: name, address, percent (đại diện),
    left/right/case (tuỳ chọn).
  - `BatterySample` — `{deviceId, timestamp, percent}`.
  - `BluetoothBatteryReader` — chạy system_profiler, parse JSON →
    `[BluetoothDevice]`. Hàm parse tách riêng khỏi I/O để test bằng fixture.
  - `UsageHistoryStore` — append mẫu, đọc/ghi JSON ở
    `~/Library/Application Support/BatteryMenuBar/history.json`, prune > 7 ngày.
  - `UsageEstimator` — hàm thuần: nhận lịch sử 1 thiết bị → `avgRate`
    (%/giờ) + ETA tới ngưỡng + trạng thái (charging / đủ dữ liệu chưa).
  - `Preferences` — ngưỡng qua UserDefaults.
  - `BatteryMonitor` — timer poll 60s, ghi mẫu vào store, phát hiện
    thiết bị chuyển trạng thái xuống dưới ngưỡng (edge-trigger, tránh
    spam noti), callback cập nhật UI.
  - `NotificationManager` — bọc UserNotifications.

- **Executable `battery`** (UI, AppKit):
  - `main.swift` + `AppDelegate` — wiring, tạo NSApplication accessory.
  - `MenuBarController` — NSStatusItem: icon xanh/đỏ, tên thiết bị thấp
    cạnh icon, menu liệt kê thiết bị + % + ETA, submenu chọn ngưỡng, Quit.

## Thuật toán ước lượng (UsageEstimator)

Cho lịch sử 1 thiết bị, 7 ngày gần nhất, đã sort theo thời gian:

1. Duyệt từng cặp liên tiếp `(sᵢ, sᵢ₊₁)`.
2. Cặp hợp lệ "đang xả" khi: Δt = tᵢ₊₁ − tᵢ nằm trong `(0, 10 phút]`
   (loại khoảng ngắt kết nối), và `pctᵢ₊₁ ≤ pctᵢ` (không tăng = không sạc).
3. Cộng dồn `totalDrop += (pctᵢ − pctᵢ₊₁)`, `totalHours += Δt`.
4. `avgRate = totalDrop / totalHours` (%/giờ).
   Nếu `totalHours < 0.5h` → `.insufficientData`.
5. Trạng thái hiện tại: nếu mẫu mới nhất > mẫu liền trước → `.charging`.
6. ETA: nếu charging → charging; nếu `pct ≤ threshold` → `.needsCharge`;
   nếu `avgRate ≤ 0` → insufficient; ngược lại
   `remainingHours = (pct − threshold) / avgRate` → `.estimate(hours)`.

Xử lý đúng kịch bản 60%→40% rồi sạc: đoạn 60→40 tính vào xả, đoạn sạc
bị loại, ETA tính từ mức pin hiện tại tới ngưỡng.

## Hiển thị menu (mỗi thiết bị)

- `.charging` → "🔌 Đang sạc"
- `.needsCharge` → "⚠️ Cần sạc ngay"
- `.insufficientData` → "Đang thu thập dữ liệu…"
- `.estimate(h)` → "Còn ~Xh Ym đến {ngưỡng}%"

Icon menu bar: xanh khi mọi thiết bị ≥ ngưỡng; đỏ + "{tên} {pct}%" khi có
thiết bị dưới ngưỡng.

## Xử lý lỗi

- system_profiler lỗi / timeout → giữ dữ liệu cũ, log.
- Thiết bị không có pin → không hiển thị % (hoặc "—").
- Không có thiết bị kết nối → menu hiện "Không có thiết bị Bluetooth".
- history.json hỏng → bỏ qua, khởi tạo lại.

## Test

- `UsageEstimatorTests`: avgRate, ETA, loại charging/gap, insufficient data,
  kịch bản 60→40→sạc.
- `BluetoothBatteryReaderTests`: parse JSON fixture (thiết bị thường +
  AirPods L/R/case, thiết bị không pin, danh sách rỗng).

## Đóng gói

`build.sh`: `swift build -c release` → tạo `Battery.app/Contents/{MacOS,
Info.plist,Resources}`, copy binary, Info.plist với `LSUIElement=true`,
`CFBundleIdentifier`. Chạy `open Battery.app` để verify icon xuất hiện.

## Ngoài phạm vi (YAGNI)

Auto-launch khi đăng nhập, biểu đồ lịch sử pin, hỗ trợ thiết bị classic
không expose pin, sync nhiều máy.
