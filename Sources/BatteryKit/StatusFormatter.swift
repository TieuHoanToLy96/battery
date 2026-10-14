import Foundation

/// Chuyển kết quả ước lượng thành chuỗi hiển thị tiếng Việt.
public struct StatusFormatter {

    public init() {}

    /// Dòng mô tả ETA cho một thiết bị.
    public func etaText(_ estimate: UsageEstimator.Estimate, threshold: Int) -> String {
        switch estimate {
        case .charging:
            return "🔌 Đang sạc"
        case .needsCharge:
            return "⚠️ Cần sạc ngay"
        case .insufficientData:
            return "Đang thu thập dữ liệu…"
        case .estimate(let hours):
            return "Còn \(hoursText(hours)) đến \(threshold)%"
        }
    }

    /// Dòng hiển thị khi % là giá trị cuối cùng đã biết (stale).
    public func staleText(_ lastUpdated: Date?, now: Date) -> String {
        guard let lastUpdated else { return "⏳ Pin gần nhất (cũ)" }
        let minutes = Int(max(0, now.timeIntervalSince(lastUpdated)) / 60)
        if minutes < 1 { return "⏳ Pin gần nhất · vừa xong" }
        if minutes < 60 { return "⏳ Pin gần nhất · \(minutes)m trước" }
        let h = minutes / 60
        let m = minutes % 60
        if h < 24 {
            return m == 0
                ? "⏳ Pin gần nhất · \(h)h trước"
                : "⏳ Pin gần nhất · \(h)h \(m)m trước"
        }
        return "⏳ Pin gần nhất · \(h / 24) ngày trước"
    }

    /// Định dạng số giờ thành "~Xh Ym". Nếu ≥ 24h thì hiện "~N ngày Xh Ym".
    public func hoursText(_ hours: Double) -> String {
        let totalMinutes = max(0, Int((hours * 60).rounded()))
        let days = totalMinutes / (24 * 60)
        let h = (totalMinutes % (24 * 60)) / 60
        let m = totalMinutes % 60

        if days > 0 {
            var parts = ["\(days) ngày"]
            if h > 0 { parts.append("\(h)h") }
            if m > 0 { parts.append("\(m)m") }
            return "~" + parts.joined(separator: " ")
        }
        if h == 0 { return "~\(m)m" }
        if m == 0 { return "~\(h)h" }
        return "~\(h)h \(m)m"
    }

    /// Nhãn một dòng cho thiết bị trong menu: "Tên — 80%".
    public func deviceLabel(_ device: BluetoothDevice) -> String {
        if let pct = device.percent {
            return "\(device.name) — \(pct)%"
        }
        return "\(device.name) — —"
    }

    /// Chi tiết pin thành phần cho AirPods (nếu có), vd "L 80% · R 75% · Case 90%".
    public func componentsText(_ device: BluetoothDevice) -> String? {
        var parts: [String] = []
        if let l = device.left { parts.append("L \(l)%") }
        if let r = device.right { parts.append("R \(r)%") }
        if let c = device.caseLevel { parts.append("Case \(c)%") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
