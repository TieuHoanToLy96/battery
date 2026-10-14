import Foundation

/// Ước lượng thời gian sử dụng pin còn lại dựa trên lịch sử xả.
public struct UsageEstimator {

    /// Kết quả ước lượng cho một thiết bị.
    public enum Estimate: Equatable {
        /// Đang sạc (pin tăng so với mẫu gần nhất).
        case charging
        /// Pin đã ở/ dưới ngưỡng — cần sạc ngay.
        case needsCharge
        /// Chưa đủ lịch sử để ước lượng.
        case insufficientData
        /// Còn khoảng `hours` giờ tới khi chạm ngưỡng.
        case estimate(hours: Double)
    }

    /// Khoảng cách tối đa giữa hai mẫu để coi là liên tục (giây).
    /// Lớn hơn mức này coi như có đoạn ngắt kết nối, không tính vào xả.
    public static let maxGapSeconds: TimeInterval = 10 * 60

    /// Tối thiểu số giờ dữ liệu xả cần có để đưa ra ước lượng.
    public static let minDischargeHours: Double = 0.5

    /// Tối thiểu số giờ thực quan sát được để ước lượng theo thời gian thực.
    public static let minSpanHours: Double = 0.5

    public init() {}

    /// Tốc độ xả trung bình (%/giờ) tính trên các đoạn xả hợp lệ.
    /// Trả về nil nếu không đủ dữ liệu.
    ///
    /// - Parameters:
    ///   - samples: lịch sử mẫu của MỘT thiết bị (sẽ được sort theo thời gian).
    public func averageDischargeRate(samples: [BatterySample]) -> Double? {
        let sorted = samples.sorted { $0.timestamp < $1.timestamp }
        guard sorted.count >= 2 else { return nil }

        var totalDrop = 0.0
        var totalHours = 0.0

        for i in 0..<(sorted.count - 1) {
            let a = sorted[i]
            let b = sorted[i + 1]
            let dt = b.timestamp.timeIntervalSince(a.timestamp)

            // Loại cặp có khoảng cách quá lớn (ngắt kết nối) hoặc không hợp lệ.
            guard dt > 0, dt <= Self.maxGapSeconds else { continue }
            // Chỉ tính đoạn đang xả: pin không tăng.
            guard b.percent <= a.percent else { continue }

            totalDrop += Double(a.percent - b.percent)
            totalHours += dt / 3600.0
        }

        // Dùng epsilon để tránh sai số dấu phẩy động ngay tại biên (vd đúng 30 phút).
        guard totalHours >= Self.minDischargeHours - 1e-9, totalDrop > 0 else { return nil }
        return totalDrop / totalHours
    }

    /// Tốc độ tụt pin theo THỜI GIAN THỰC (wall-clock) — tính trên mỗi giờ
    /// đồng hồ thật, gồm cả lúc idle, ngắt kết nối, cất đi. Phản ánh "thói
    /// quen dùng": tổng % đã tiêu / tổng số giờ thực quan sát được.
    public func averageWallClockRate(samples: [BatterySample]) -> Double? {
        let sorted = samples.sorted { $0.timestamp < $1.timestamp }
        guard let first = sorted.first, let last = sorted.last else { return nil }

        let spanHours = last.timestamp.timeIntervalSince(first.timestamp) / 3600.0
        guard spanHours >= Self.minSpanHours - 1e-9 else { return nil }

        var totalDrop = 0.0
        for i in 0..<(sorted.count - 1) {
            let drop = Double(sorted[i].percent - sorted[i + 1].percent)
            if drop > 0 { totalDrop += drop }   // chỉ cộng phần tụt (bỏ lúc sạc)
        }
        guard totalDrop > 0 else { return nil }
        return totalDrop / spanHours
    }

    /// Ước lượng thời gian thực tế còn lại tới `threshold` (theo thói quen dùng).
    ///
    /// - Parameters:
    ///   - samples: lịch sử mẫu của thiết bị.
    ///   - currentPercent: % pin hiện tại.
    ///   - threshold: ngưỡng cảnh báo (vd 20).
    public func estimate(
        samples: [BatterySample],
        currentPercent: Int,
        threshold: Int
    ) -> Estimate {
        let sorted = samples.sorted { $0.timestamp < $1.timestamp }

        // Suy ra đang sạc: pin TĂNG giữa hai mẫu liên tiếp GẦN nhau (≤ 10 phút).
        // Bước nhảy do reconnect sau khi sạc trong hộp (cách nhau hàng giờ)
        // KHÔNG bị coi là đang sạc.
        if sorted.count >= 2 {
            let last = sorted[sorted.count - 1]
            let prev = sorted[sorted.count - 2]
            let dt = last.timestamp.timeIntervalSince(prev.timestamp)
            if last.percent > prev.percent, dt > 0, dt <= Self.maxGapSeconds {
                return .charging
            }
        }

        if currentPercent <= threshold { return .needsCharge }

        // Dùng tốc độ theo thời gian thực (thói quen dùng).
        guard let rate = averageWallClockRate(samples: sorted), rate > 0 else {
            return .insufficientData
        }

        let remaining = Double(currentPercent - threshold) / rate
        return .estimate(hours: remaining)
    }
}
