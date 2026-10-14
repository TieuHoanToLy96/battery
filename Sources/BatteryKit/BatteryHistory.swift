import Foundation

/// Dữ liệu biểu đồ trong khoảng thời gian cố định; không nối qua khoảng mất dữ liệu.
public struct BatteryHistory {
    public let start: Date
    public let end: Date
    public let segments: [[BatterySample]]

    public init(samples: [BatterySample], deviceId: String, duration: TimeInterval, now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-duration)
        start = cutoff
        end = now
        let points = samples.filter {
            $0.deviceId == deviceId && $0.timestamp >= cutoff && $0.timestamp <= now
                && (0...100).contains($0.percent)
        }.sorted { $0.timestamp < $1.timestamp }
        var groups: [[BatterySample]] = []
        for point in points {
            if let previous = groups.last?.last,
               point.timestamp.timeIntervalSince(previous.timestamp) <= 10 * 60 {
                groups[groups.count - 1].append(point)
            } else {
                groups.append([point])
            }
        }
        segments = groups
    }
}
