# AGENTS.md — Battery (Bluetooth Battery + YouTube Menu Bar App)

Tài liệu cho AI agent / lập trình viên tiếp nhận dự án. Đọc file này trước khi sửa code.

---

## 1. Tổng quan

App **menu bar macOS** (không hiện trên Dock — `LSUIElement`) viết bằng **Swift + AppKit**, build bằng **Swift Package Manager** (không dùng Xcode project).

Hai nhóm chức năng chính:
1. **Pin Bluetooth** — hiện % pin các thiết bị Bluetooth đang kết nối, cảnh báo pin thấp, ước lượng thời gian dùng còn lại theo thói quen.
2. **Điều khiển YouTube/Chrome** — card "đang phát" (now playing), tìm & phát video, equalizer, loop, đổi output/âm lượng.

- **Ngôn ngữ UI & comment: tiếng Việt.**
- **macOS 13+** (máy dev: macOS 15.6 Sequoia, SDK 26.2).
- Giao diện kiểu **glass** (NSVisualEffectView `.hudWindow` + thẻ bo góc viền gradient).

---

## 2. Build / Run / Test

```bash
swift build                 # build debug
swift test                  # chạy unit test (BatteryKitTests)
./build.sh                  # tạo Battery.app bundle (release) + icon + Info.plist
./install.sh                # build.sh → copy /Applications + LaunchAgent (tự chạy khi login)
./uninstall.sh              # gỡ app + LaunchAgent (giữ lịch sử pin)
./make-icon.sh              # vẽ lại AppIcon.icns từ make-icon.swift

# Cờ debug của executable:
.build/debug/battery --once        # in thiết bị + pin rồi thoát
.build/debug/battery --bt-json     # in JSON pin (dùng nội bộ, xem mục 6)
.build/debug/battery --search "x"  # test YouTube search
```

**Luôn chạy `./install.sh` sau khi sửa** để thấy thay đổi (nó build release + thay bản trong /Applications + reload LaunchAgent). `swift build` chỉ build debug, KHÔNG cập nhật bản đã cài.

---

## 3. Kiến trúc: hai target

`Package.swift` khai báo:

| Target | Loại | Vai trò |
|---|---|---|
| **BatteryKit** | library | Logic thuần + đọc pin (test được). Link `IOBluetooth`. |
| **battery** | executable | UI AppKit + tích hợp hệ thống (CoreAudio, WebKit, Chrome, media-control). Depends BatteryKit. |
| **BatteryKitTests** | test | Unit test cho logic thuần trong BatteryKit. |

**Quy tắc:** logic thuần/test được → `BatteryKit`. UI và thứ phụ thuộc hệ thống phức tạp → `battery`. Hàm "thuần" (vd `UsageEstimator`, `*Reader.parse`, `BatteryMonitor.makeStatus`) tách khỏi I/O để test bằng fixture.

---

## 4. Catalog tính năng → file

### Pin Bluetooth
- **Đọc pin đa nguồn** (gộp, ưu tiên nguồn live): `IOBluetoothFrameworkReader` (chính, live) → `IORegistryBatteryReader` → `BluetoothBatteryReader` (system_profiler). Gộp qua `CompositeBatteryReader` (`BatteryDeviceReading.swift`), dedup theo địa chỉ chuẩn hoá.
- **Poll định kỳ 60s + lúc kết nối**: `BatteryMonitor` (timer + `BluetoothConnectionObserver`).
- **Lịch sử 30 ngày, tự prune**: `UsageHistoryStore` (JSON ở `~/Library/Application Support/BatteryMenuBar/history.json`).
- **Ước lượng thời gian thực (thói quen)**: `UsageEstimator.averageWallClockRate` → ETA theo wall-clock (gồm idle/ngắt kết nối). `estimate()` cũng suy luận charging / needsCharge / insufficient.
- **Cảnh báo pin thấp**: `NotificationManager` (notification) + icon menu bar đỏ (`MenuBarController.refreshStatusItem`, ưu tiên: pin thấp > nhạc > thường).
- **Ngưỡng chỉnh được**: `Preferences.threshold`, menu trong `PopoverViewController`.
- **Icon loại thiết bị + badge "đang phát"**: `DeviceIconMapper`, `DeviceRowView` (badge waveform animate khi `AudioActivity.isActive`).

### YouTube / Chrome / Audio
- **Now Playing card** (artwork, tên chạy chữ, thanh tua, prev/play/next, ±bước tua, loop): `NowPlayingView`. Dữ liệu từ `NowPlaying` + `NowPlayingController` (gọi CLI `media-control`).
- **Tìm & phát video**: ô search → `YouTubeSearch` (scrape trang kết quả, parse `ytInitialData`) → flyout `SearchResultRowView` → mở/thay tab YouTube (`ChromeController.playInExistingYouTubeTab`, kèm `&list=RD` để có next/prev).
- **Equalizer**: `EQ` (preset) → `ChromeController.applyEQ` (tiêm Web Audio BiquadFilter vào tab).
- **Loop / next / prev**: `ChromeController.setLoop/youtubeNext/youtubePrevious` (Chrome JS).
- **Đổi output / âm lượng**: `AudioActivity` (CoreAudio) + `SystemVolume` (AppleScript) + `VolumeRowView`.
- **Waveform trên menu bar khi phát nhạc**: `MenuBarController` (poll `media-control` mỗi 4s).

### UI dùng chung
- `GlassCard` (vẽ nền thẻ glass), `GlassCardContainer` (bọc nhóm), `MenuRowView` (dòng cài đặt + flyout), `MarqueeLabel` (chữ chạy), `SeekBarView` (thanh kéo).

---

## 5. Thành phần chính (từng file)

**BatteryKit:**
- `BluetoothDevice` — model thiết bị (address chuẩn hoá, percent, left/right/case, minorType). `normalizeAddress` để merge giữa nguồn.
- `BatteryDeviceReading` — protocol reader + `CompositeBatteryReader` (gộp, ưu tiên nguồn trước, bù trường thiếu).
- `IOBluetoothFrameworkReader` — đọc `IOBluetoothDevice.pairedDevices()` + `batteryPercentSingle/Combined/Left/Right/Case` (nguồn LIVE, giống Control Center).
- `IORegistryBatteryReader` — `ioreg -a -k BatteryPercent` (plist).
- `BluetoothBatteryReader` — `system_profiler SPBluetoothDataType -json`.
- `BluetoothConnectionObserver` — IOBluetooth connect notifications → trigger poll.
- `BatteryMonitor` — orchestrator: poll, ghi history, tính `DeviceStatus`, edge-trigger cảnh báo. `makeStatus` thuần (có `freshWindow` 5 phút: thiết bị HFP bỏ trống pin 1 nhịp vẫn coi tươi).
- `UsageHistoryStore` — lưu/prune mẫu (`defaultRetention` 30 ngày).
- `UsageEstimator` — tính tốc độ xả. `averageWallClockRate` (dùng cho ETA theo thói quen), `averageDischargeRate` (giờ-xả thuần, giữ để đối chiếu).
- `StatusFormatter` — format ETA / "Pin gần nhất" / nhãn thiết bị.
- `Preferences` — UserDefaults (xem mục 8).
- `NotificationManager` — UserNotifications.
- `YouTubeSearch` — scrape + parse kết quả (hàm `parse` thuần, byte UTF8 để nhanh trên HTML ~1.6MB).
- `BatteryHistory` — (logic biểu đồ lịch sử — hiện KHÔNG dùng ở UI, giữ lại + có test).

**battery (executable):**
- `main.swift` — entry, xử lý cờ `--bt-json/--once/--search`, dựng NSApplication `.accessory`.
- `AppDelegate` — khởi tạo monitor (với `IOBluetoothSubprocessReader` thay cho in-process), cài Edit menu (Cmd+A/C/V/X).
- `MenuBarController` — NSStatusItem + NSPopover glass + icon ưu tiên + poll nhạc 4s + reapply EQ/loop.
- `PopoverViewController` — nội dung popover: search, now playing, danh sách thiết bị, thẻ Cài đặt; poll now-playing 1s khi mở.
- `NowPlayingView` / `NowPlaying` / `NowPlayingController` — card + model + đọc `media-control`.
- `ChromeController` — mọi tương tác Chrome (AppleScript: set URL tab, JS next/prev/loop/EQ, đọc video id).
- `AudioActivity` / `SystemVolume` — CoreAudio (thiết bị đang phát, output) + AppleScript volume.
- `EQ` — preset equalizer (gains theo dải tần).
- `DeviceRowView` / `SearchResultRowView` / `VolumeRowView` / `MenuRowView` — các view.
- `GlassCard` / `GlassCardContainer` / `MarqueeLabel` / `SeekBarView` / `DeviceIconMapper` — UI dùng chung.
- `IOBluetoothSubprocessReader` — spawn chính app `--bt-json` để đọc IOBluetooth trong tiến trình TƯƠI (xem mục 6, quan trọng).

---

## 6. ⚠️ Giới hạn macOS & workaround (BÀI HỌC — đọc kỹ)

Đây là các "bẫy" đã tốn công phát hiện. ĐỪNG sửa lại về cách "ngây thơ".

1. **IOBluetooth cache pin theo tiến trình.** `batteryPercentSingle` trong một tiến trình sống lâu (app) KHÔNG cập nhật; tiến trình mới luôn đọc đúng. → Monitor dùng `IOBluetoothSubprocessReader` spawn `battery --bt-json` mỗi lần poll (tiến trình tươi). KHÔNG đọc IOBluetooth in-process trong app.
2. **Tai nghe HFP báo pin chập chờn / chỉ qua IOBluetooth.** system_profiler và ioreg thường KHÔNG có pin tai nghe; `IOBluetoothFrameworkReader` mới có. K380 (BT classic) KHÔNG expose pin ở đâu cả → không hiện là đúng.
3. **Không có cờ "charging" tin cậy.** Suy luận: pin tăng giữa 2 mẫu ≤10 phút = đang sạc (guard 10 phút để tránh nhầm reconnect-sau-khi-sạc).
4. **MediaRemote bị Apple chặn từ macOS 15.4** cho app bên thứ ba. → Dùng CLI **`media-control`** (Homebrew, `ungive/mediaremote-adapter`) chạy qua `/usr/bin/perl` (= `com.apple.perl`, được phép). App shell-out tới `media-control`.
5. **`elapsedTime` của media-control là snapshot tại `timestamp`**, không phải vị trí sống. → Tính live = `elapsed + (now - timestamp)` khi đang phát (xem `NowPlayingView.refreshPosition`).
6. **Menu bar icon template bị ép đơn sắc** → `contentTintColor` đỏ bị bỏ qua. Khi cảnh báo dùng ảnh KHÔNG template tô đỏ, và icon inline trong `attributedTitle` (NSTextAttachment) để căn giữa với chữ.
7. **CoreAudio VolumeScalar không đọc được cho nhiều tai nghe BT.** → Dùng AppleScript `set/get volume` (`SystemVolume`).
8. **NSMenu flyout là MODAL — chiếm bàn phím & không chạy callback async.** → Thumbnail search phải tải SẴN trước khi bung menu. EQ/loop/next-prev cần Chrome, KHÔNG dùng khi menu đang mở.
9. **Chrome JS (`execute ... javascript`) bị TẮT mặc định.** Cần user bật **View → Developer → Allow JavaScript from Apple Events** + cấp quyền Automation. next/prev/loop/EQ phụ thuộc cái này; `playInExistingYouTubeTab` (set URL) thì KHÔNG cần JS.
10. **Video YouTube đơn lẻ không có next/prev** (không hàng đợi). → Mở kèm `&list=RD<id>` (Mix) để có autoplay queue.
11. **Nhiều MV YouTube chặn nhúng embed** (lỗi 152) dù oEmbed 200. (Tính năng video-thay-thumbnail đã BỎ vì lý do này.)
12. **App accessory (`LSUIElement`) không có main menu** → Cmd+A/C/V/X không route tới text field → phải cài Edit menu thủ công (`AppDelegate.installEditMenu`).
13. **NSTextAttachment/clip:** `MarqueeLabel` clip vào bounds để chữ chạy không đè view khác.

---

## 7. Luồng dữ liệu

**Pin:** `BatteryMonitor.pollNow` (60s / connect / manual) → `reader.fetch()` (nền) → `handle()` (main): ghi history, `makeStatus` mỗi thiết bị → `onUpdate(statuses)` → `MenuBarController.render` → `updateButton` + (nếu popover mở) `PopoverViewController.render`.

**Now playing:** `PopoverViewController` poll `media-control get` mỗi 1s khi popover mở → `NowPlayingView.update`. `MenuBarController` poll mỗi 4s khi đóng (để waveform + reapply EQ/loop).

**Search:** Enter → `YouTubeSearch.search` (HTTP) → tải sẵn thumbnail → NSMenu flyout → click → `ChromeController.playInExistingYouTubeTab`.

---

## 8. Preferences (UserDefaults)

| Key | Kiểu | Ý nghĩa |
|---|---|---|
| `warningThreshold` | Int | Ngưỡng cảnh báo % |
| `skipSeconds` | Int | Bước tua (10/20/30/60/300) |
| `eqGains` | [Double] | Gain 6 dải EQ |
| `lastSearchQuery` | String | Từ khoá search gần nhất |
| `loopEnabled` | Bool | Lặp video |

`availableThresholds / availableSkipSteps / EQ.presets / EQ.bands` là hằng số đi kèm.

---

## 9. Thêm tính năng — hướng dẫn

- **Logic pin/tính toán mới** → `BatteryKit`, viết hàm thuần + test trong `Tests/BatteryKitTests`.
- **Dòng cài đặt mới** → thêm `MenuRowView` trong `PopoverViewController.settingsRows` (flyout = NSMenu, hoặc onClick). Thêm key vào `Preferences`.
- **Điều khiển Chrome mới** → thêm hàm vào `ChromeController` (dùng `runYouTubeJS` cho JS, hoặc AppleScript thuần cho thao tác không cần JS). Nhớ: cần "Allow JavaScript from Apple Events".
- **Tương tác định kỳ khi popover đóng** → thêm vào `MenuBarController.checkMusic` (4s). Khi popover mở → `PopoverViewController.pollNowPlaying` (1s).
- Giữ **comment tiếng Việt**, style khớp code quanh đó. Chạy `swift test` + `./install.sh` trước khi báo xong.

---

## 10. Trạng thái hiện tại / TODO đang dở

- YouTube search: 1 trang ~19 video. Đang định thêm **phân trang (continuation token + youtubei API)** để gộp ~50 kết quả + làm **row kết quả ngắn lại** cho dễ cuộn. (Chưa xong.)
- `BatteryHistory.swift` + test còn đó nhưng UI biểu đồ đã gỡ (có thể xoá nếu không dùng lại).
