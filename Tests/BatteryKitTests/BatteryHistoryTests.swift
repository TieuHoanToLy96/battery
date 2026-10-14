import XCTest
@testable import BatteryKit

final class BatteryHistoryTests: XCTestCase {
    func testFiltersDeviceAndWindowAndSplitsDisconnectedIntervals() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        func sample(_ id: String, _ age: Double, _ percent: Int) -> BatterySample {
            BatterySample(deviceId: id, timestamp: now.addingTimeInterval(-age), percent: percent)
        }
        let samples = [sample("a", 60, 60), sample("b", 120, 30),
                       sample("a", 900, 80), sample("a", 960, 81),
                       sample("a", 90_000, 90), sample("a", -60, 50), sample("a", 30, 101)]
        let history = BatteryHistory(samples: samples, deviceId: "a", duration: 86_400, now: now)
        XCTAssertEqual(history.segments.map { $0.map(\.percent) }, [[81, 80], [60]])
        XCTAssertEqual(history.start, now.addingTimeInterval(-86_400))
        XCTAssertEqual(history.end, now)
    }

    func testEmptyAndSingleSampleRemainRepresentable() {
        let now = Date()
        XCTAssertTrue(BatteryHistory(samples: [], deviceId: "a", duration: 60, now: now).segments.isEmpty)
        let sample = BatterySample(deviceId: "a", timestamp: now, percent: 0)
        XCTAssertEqual(BatteryHistory(samples: [sample], deviceId: "a", duration: 60, now: now).segments, [[sample]])
    }
}
