import XCTest
@testable import BatteryKit

final class BatteryMonitorStatusTests: XCTestCase {

    private let estimator = UsageEstimator()
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func samples(_ points: [(minutes: Double, percent: Int)], id: String) -> [BatterySample] {
        points.map {
            BatterySample(deviceId: id, timestamp: base.addingTimeInterval($0.minutes * 60), percent: $0.percent)
        }
    }

    func testFreshDeviceComputesEstimate() {
        let hist = samples([
            (0, 100), (5, 95), (10, 90), (15, 85), (20, 80), (25, 75), (30, 70),
        ], id: "a")
        let device = BluetoothDevice(address: "a", name: "Mouse", percent: 70)

        let status = BatteryMonitor.makeStatus(
            device: device, history: hist, threshold: 20, estimator: estimator
        )
        let s = try! XCTUnwrap(status)
        XCTAssertFalse(s.isStale)
        XCTAssertEqual(s.device.percent, 70)
        if case .estimate = s.estimate {} else { XCTFail("mong đợi .estimate, nhận \(s.estimate)") }
        XCTAssertFalse(s.isLow)
    }

    func testStaleFallbackUsesLastKnown() {
        // Thiết bị hiện không báo pin (percent nil) nhưng có lịch sử.
        let hist = samples([(0, 90), (5, 85)], id: "k380")
        let device = BluetoothDevice(address: "k380", name: "Keyboard K380", percent: nil)

        let status = BatteryMonitor.makeStatus(
            device: device, history: hist, threshold: 20, estimator: estimator
        )
        let s = try! XCTUnwrap(status)
        XCTAssertTrue(s.isStale)
        XCTAssertEqual(s.device.percent, 85)                 // dùng giá trị cuối
        XCTAssertEqual(s.lastUpdated, base.addingTimeInterval(5 * 60))
        XCTAssertFalse(s.isLow)                              // 85 > 20
    }

    func testRecentLastKnownNotStale() {
        // Thiết bị hiện không báo pin nhưng mẫu cuối chỉ 1 phút trước => vẫn tươi.
        let hist = samples([(0, 90), (5, 85)], id: "hfp")   // mẫu cuối tại base+5 phút
        let device = BluetoothDevice(address: "hfp", name: "Tai nghe", percent: nil)
        let now = base.addingTimeInterval(6 * 60)           // 1 phút sau mẫu cuối

        let s = try! XCTUnwrap(BatteryMonitor.makeStatus(
            device: device, history: hist, threshold: 20, estimator: estimator, now: now
        ))
        XCTAssertFalse(s.isStale)            // không bị đánh dấu cũ
        XCTAssertEqual(s.device.percent, 85) // dùng giá trị gần nhất
    }

    func testOldLastKnownIsStale() {
        // Mẫu cuối đã 10 phút trước (> cửa sổ 5 phút) => coi là cũ.
        let hist = samples([(0, 90)], id: "k")
        let device = BluetoothDevice(address: "k", name: "Bàn phím", percent: nil)
        let now = base.addingTimeInterval(10 * 60)

        let s = try! XCTUnwrap(BatteryMonitor.makeStatus(
            device: device, history: hist, threshold: 20, estimator: estimator, now: now
        ))
        XCTAssertTrue(s.isStale)
    }

    func testStaleLowStillMarkedLow() {
        let hist = samples([(0, 12)], id: "x")
        let device = BluetoothDevice(address: "x", name: "Old Mouse", percent: nil)

        let s = try! XCTUnwrap(BatteryMonitor.makeStatus(
            device: device, history: hist, threshold: 20, estimator: estimator
        ))
        XCTAssertTrue(s.isStale)
        XCTAssertTrue(s.isLow)                              // 12 <= 20
        XCTAssertEqual(s.estimate, .insufficientData)       // không suy ETA từ giá trị cũ
    }

    func testNoDataReturnsNil() {
        let device = BluetoothDevice(address: "none", name: "Keyboard", percent: nil)
        XCTAssertNil(BatteryMonitor.makeStatus(
            device: device, history: [], threshold: 20, estimator: estimator
        ))
    }

    func testHoursTextWithDays() {
        let f = StatusFormatter()
        XCTAssertEqual(f.hoursText(27.5), "~1 ngày 3h 30m")   // 27h30m
        XCTAssertEqual(f.hoursText(24), "~1 ngày")
        XCTAssertEqual(f.hoursText(48 + 2.0/60), "~2 ngày 2m") // 48h02m
        XCTAssertEqual(f.hoursText(5.5), "~5h 30m")            // < 24h giữ nguyên
    }

    func testStaleTextFormatting() {
        let f = StatusFormatter()
        let now = base.addingTimeInterval(3 * 3600 + 25 * 60) // 3h25m sau
        XCTAssertEqual(f.staleText(base, now: now), "⏳ Pin gần nhất · 3h 25m trước")
        XCTAssertEqual(f.staleText(base.addingTimeInterval(now.timeIntervalSince(base) - 30), now: now), "⏳ Pin gần nhất · vừa xong")
        XCTAssertEqual(f.staleText(nil, now: now), "⏳ Pin gần nhất (cũ)")
    }

    func testLastSampleReturnsMostRecent() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bt-\(UUID().uuidString)")
            .appendingPathComponent("h.json")
        let store = UsageHistoryStore(fileURL: url)
        store.append(BatterySample(deviceId: "a", timestamp: base, percent: 80))
        store.append(BatterySample(deviceId: "a", timestamp: base.addingTimeInterval(600), percent: 60))
        store.append(BatterySample(deviceId: "b", timestamp: base, percent: 50))

        XCTAssertEqual(store.lastSample(for: "a")?.percent, 60)
        XCTAssertEqual(store.lastSample(for: "b")?.percent, 50)
        XCTAssertNil(store.lastSample(for: "c"))

        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
