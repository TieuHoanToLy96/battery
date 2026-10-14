import XCTest
@testable import BatteryKit

final class StatusFormatterTests: XCTestCase {

    private let f = StatusFormatter()

    func testHoursText() {
        XCTAssertEqual(f.hoursText(0), "~0m")
        XCTAssertEqual(f.hoursText(0.5), "~30m")
        XCTAssertEqual(f.hoursText(1), "~1h")
        XCTAssertEqual(f.hoursText(1.5), "~1h 30m")
        XCTAssertEqual(f.hoursText(2.25), "~2h 15m")
    }

    func testEtaText() {
        XCTAssertEqual(f.etaText(.charging, threshold: 20), "🔌 Đang sạc")
        XCTAssertEqual(f.etaText(.needsCharge, threshold: 20), "⚠️ Cần sạc ngay")
        XCTAssertEqual(f.etaText(.insufficientData, threshold: 20), "Đang thu thập dữ liệu…")
        XCTAssertEqual(f.etaText(.estimate(hours: 1.5), threshold: 20), "Còn ~1h 30m đến 20%")
    }

    func testDeviceLabelAndComponents() {
        let airpods = BluetoothDevice(
            address: "x", name: "AirPods", percent: 65, left: 70, right: 65, caseLevel: 90
        )
        XCTAssertEqual(f.deviceLabel(airpods), "AirPods — 65%")
        XCTAssertEqual(f.componentsText(airpods), "L 70% · R 65% · Case 90%")

        let keyboard = BluetoothDevice(address: "y", name: "Keyboard", percent: 85)
        XCTAssertEqual(f.deviceLabel(keyboard), "Keyboard — 85%")
        XCTAssertNil(f.componentsText(keyboard))
    }
}

final class UsageHistoryStoreTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("battery-test-\(UUID().uuidString)")
            .appendingPathComponent("history.json")
    }

    func testAppendAndPersist() {
        let url = tempURL()
        let store = UsageHistoryStore(fileURL: url)
        store.append(BatterySample(deviceId: "a", timestamp: base, percent: 80))
        store.append(BatterySample(deviceId: "b", timestamp: base, percent: 50))

        // Đọc lại từ đĩa bằng store mới.
        let reloaded = UsageHistoryStore(fileURL: url)
        XCTAssertEqual(reloaded.samples(for: "a").count, 1)
        XCTAssertEqual(reloaded.samples(for: "a").first?.percent, 80)
        XCTAssertEqual(reloaded.allSamples.count, 2)

        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testPruneOldSamples() {
        let url = tempURL()
        let store = UsageHistoryStore(fileURL: url, retention: 7 * 24 * 60 * 60)

        let old = base
        let recent = base.addingTimeInterval(8 * 24 * 60 * 60) // 8 ngày sau

        store.append(BatterySample(deviceId: "a", timestamp: old, percent: 90))
        // append mẫu "recent" sẽ prune mẫu cũ hơn 7 ngày so với recent.
        store.append(BatterySample(deviceId: "a", timestamp: recent, percent: 40))

        XCTAssertEqual(store.samples(for: "a").count, 1)
        XCTAssertEqual(store.samples(for: "a").first?.percent, 40)

        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testCorruptFileTreatedAsEmpty() throws {
        let url = tempURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data("garbage".utf8).write(to: url)

        let store = UsageHistoryStore(fileURL: url)
        XCTAssertTrue(store.allSamples.isEmpty)

        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
