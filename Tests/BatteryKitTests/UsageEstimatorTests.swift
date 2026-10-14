import XCTest
@testable import BatteryKit

final class UsageEstimatorTests: XCTestCase {

    private let estimator = UsageEstimator()
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    /// Tạo mẫu từ danh sách (phútOffset, percent) cho một thiết bị.
    private func samples(_ points: [(minutes: Double, percent: Int)], id: String = "dev") -> [BatterySample] {
        points.map {
            BatterySample(
                deviceId: id,
                timestamp: base.addingTimeInterval($0.minutes * 60),
                percent: $0.percent
            )
        }
    }

    func testSteadyDischargeRate() {
        // 100 -> 70 trong 30 phút, cách nhau 5 phút = 60%/giờ.
        let s = samples([
            (0, 100), (5, 95), (10, 90), (15, 85), (20, 80), (25, 75), (30, 70),
        ])
        let rate = estimator.averageDischargeRate(samples: s)
        XCTAssertNotNil(rate)
        XCTAssertEqual(rate!, 60, accuracy: 0.001)
    }

    func testEstimateHoursToThreshold() {
        let s = samples([
            (0, 100), (5, 95), (10, 90), (15, 85), (20, 80), (25, 75), (30, 70),
        ])
        // rate 60%/h, từ 70% tới 20% = 50% => 50/60 giờ.
        let result = estimator.estimate(samples: s, currentPercent: 70, threshold: 20)
        guard case let .estimate(hours) = result else {
            return XCTFail("Mong đợi .estimate, nhận \(result)")
        }
        XCTAssertEqual(hours, 50.0 / 60.0, accuracy: 0.001)
    }

    func testChargingDetected() {
        // Mẫu cuối cao hơn mẫu trước => đang sạc.
        let s = samples([(0, 50), (5, 60)])
        let result = estimator.estimate(samples: s, currentPercent: 60, threshold: 20)
        XCTAssertEqual(result, .charging)
    }

    func testNeedsChargeWhenAtOrBelowThreshold() {
        let s = samples([(0, 30), (5, 25)]) // đang x, không sạc
        let result = estimator.estimate(samples: s, currentPercent: 18, threshold: 20)
        XCTAssertEqual(result, .needsCharge)
    }

    func testInsufficientDataTooShort() {
        // Chỉ 10 phút dữ liệu xả < 0.5h tối thiểu.
        let s = samples([(0, 100), (5, 95), (10, 90)])
        XCTAssertNil(estimator.averageDischargeRate(samples: s))
        let result = estimator.estimate(samples: s, currentPercent: 90, threshold: 20)
        XCTAssertEqual(result, .insufficientData)
    }

    func testLargeGapExcluded() {
        // Hai mẫu cách nhau 1 ngày (ngắt kết nối) => không tính là xả liên tục.
        let s = samples([(0, 100), (1440, 40)])
        XCTAssertNil(estimator.averageDischargeRate(samples: s))
    }

    func testChargingSegmentsExcludedFromRate() {
        // Kịch bản: xả 70->40 (30 phút, 5 phút/mẫu = 60%/h) rồi sạc lên.
        let s = samples([
            (0, 70), (5, 65), (10, 60), (15, 55), (20, 50), (25, 45), (30, 40),
            (35, 55), (40, 70), // đoạn sạc, phải bị loại
        ])
        let rate = estimator.averageDischargeRate(samples: s)
        XCTAssertNotNil(rate)
        // Chỉ đoạn xả được tính => vẫn 60%/h, không bị đoạn sạc kéo lệch.
        XCTAssertEqual(rate!, 60, accuracy: 0.001)
    }

    func testReconnectJumpNotTreatedAsCharging() {
        // 50% rồi hàng giờ sau reconnect ở 90% (sạc trong hộp) — KHÔNG phải đang sạc.
        let s = samples([(0, 50), (180, 90)])
        let result = estimator.estimate(samples: s, currentPercent: 90, threshold: 20)
        XCTAssertNotEqual(result, .charging)
        XCTAssertEqual(result, .insufficientData) // chưa có đoạn xả hợp lệ
    }

    func testTwoListeningSessionsBlendRate() {
        // Phiên 1: 60->50 (10 phút). Bỏ hộp, reconnect. Phiên 2: 90->70 (20 phút).
        let s = samples([
            (0, 60), (5, 55), (10, 50),           // phiên 1: -10% / 10 phút
            (180, 90), (185, 85), (190, 80), (195, 75), (200, 70), // phiên 2: -20% / 20 phút
        ])
        // Tốc độ xả (chỉ đoạn đang xả): 30% / 0.5h = 60%/h.
        XCTAssertEqual(estimator.averageDischargeRate(samples: s)!, 60, accuracy: 0.001)

        // Tốc độ THỰC (wall-clock): 30% tụt / 200 phút (3.333h) = 9%/h.
        XCTAssertEqual(estimator.averageWallClockRate(samples: s)!, 30.0 / (200.0 / 60.0), accuracy: 0.001)

        // ETA theo thời gian thực từ 70% tới 20% = 50 / 9 giờ.
        let result = estimator.estimate(samples: s, currentPercent: 70, threshold: 20)
        guard case let .estimate(hours) = result else {
            return XCTFail("mong đợi .estimate, nhận \(result)")
        }
        XCTAssertEqual(hours, 50.0 / (30.0 / (200.0 / 60.0)), accuracy: 0.001)
    }

    func testUnsortedSamplesHandled() {
        let s = samples([
            (30, 70), (0, 100), (15, 85), (5, 95), (25, 75), (10, 90), (20, 80),
        ])
        let rate = estimator.averageDischargeRate(samples: s)
        XCTAssertEqual(rate!, 60, accuracy: 0.001)
    }
}
