import AppKit
import BatteryKit

/// Thẻ "glass" cho một thiết bị:
/// vòng tròn kín tô theo % pin (icon loại thiết bị ở giữa, % ở dưới vòng,
/// pin tụt ngược chiều kim đồng hồ) + tên thiết bị + dòng chi tiết.
final class DeviceRowView: NSView {

    private let status: BatteryMonitor.DeviceStatus
    private let threshold: Int
    private let isActive: Bool
    private let formatter = StatusFormatter()
    private let componentsLine: String?

    static let cardWidth: CGFloat = 288
    private static let cardHeight: CGFloat = 84
    private static let leftColWidth: CGFloat = 66
    private static let ringSize: CGFloat = 38
    private static let vPad: CGFloat = 13   // padding trên/dưới trong thẻ

    init(status: BatteryMonitor.DeviceStatus, threshold: Int, isActive: Bool = false) {
        self.status = status
        self.threshold = threshold
        self.isActive = isActive
        self.componentsLine = formatter.componentsText(status.device)
        super.init(frame: NSRect(x: 0, y: 0, width: Self.cardWidth, height: Self.cardHeight))
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: Self.cardWidth).isActive = true
        heightAnchor.constraint(equalToConstant: Self.cardHeight).isActive = true
        setupActiveBadge()
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        drawCard()
        drawGauge()
        drawText()
    }

    /// Badge "đang phát" ở góc trên-phải, sóng nhạc tự nhún (animate) khi đang phát.
    private func setupActiveBadge() {
        guard isActive else { return }
        let imageView = NSImageView()
        imageView.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "đang phát")
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        imageView.contentTintColor = .systemGreen
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -13),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
        ])
        // Hiệu ứng "nhảy": các vạch sáng tắt lặp lại như equalizer.
        if #available(macOS 14.0, *) {
            imageView.addSymbolEffect(.variableColor.iterative.reversing, options: .repeating)
        }
    }

    // MARK: - Nền thẻ glass

    private func drawCard() {
        GlassCard.draw(in: bounds)
    }

    // MARK: - Vòng pin + icon + %

    private func drawGauge() {
        let colCenterX = 10 + Self.leftColWidth / 2
        let ringCenterY = bounds.height - Self.vPad - Self.ringSize / 2
        let center = NSPoint(x: colCenterX, y: ringCenterY)

        let lineWidth: CGFloat = 4.5
        let radius = Self.ringSize / 2 - lineWidth / 2
        let level = status.device.percent ?? 0
        let fraction = max(0, min(1, CGFloat(level) / 100))

        // Rãnh nền: vòng tròn kín.
        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
        track.lineWidth = lineWidth
        NSColor.white.withAlphaComponent(0.18).setStroke()
        track.stroke()

        // Cung tô: từ đỉnh (90°) theo chiều kim đồng hồ ⇒ pin tụt ngược chiều kim đồng hồ.
        if fraction > 0 {
            let fill = NSBezierPath()
            fill.appendArc(
                withCenter: center, radius: radius,
                startAngle: 90, endAngle: 90 - 360 * fraction, clockwise: true
            )
            fill.lineWidth = lineWidth
            fill.lineCapStyle = .round
            ringColor(for: level).setStroke()
            fill.stroke()
        }

        // Icon loại thiết bị ở giữa vòng (luôn sáng — thiết bị vẫn kết nối).
        if let icon = DeviceIconMapper.image(for: status.device, pointSize: 17, color: .labelColor) {
            let s = icon.size
            icon.draw(in: NSRect(x: center.x - s.width / 2, y: center.y - s.height / 2, width: s.width, height: s.height))
        }

        // % dưới vòng (luôn sáng).
        let pctStr = NSAttributedString(string: "\(level)%", attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.labelColor,
        ])
        let size = pctStr.size()
        pctStr.draw(at: NSPoint(x: colCenterX - size.width / 2, y: Self.vPad))
    }

    private func ringColor(for level: Int) -> NSColor {
        // Luôn tô theo mức pin (không xám khi giá trị gần nhất) — thiết bị
        // vẫn đang kết nối, hiển thị như Control Center của macOS.
        if level <= threshold { return .systemRed }
        if level <= 40 { return .systemOrange }
        return .systemGreen
    }

    // MARK: - Chữ bên phải

    private func drawText() {
        let textX = 10 + Self.leftColWidth + 10
        let textW = bounds.width - textX - 14

        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
        ]
        let detailAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.labelColor.withAlphaComponent(0.82),
        ]

        let detail = status.isStale
            ? formatter.staleText(status.lastUpdated, now: Date())
            : formatter.etaText(status.estimate, threshold: threshold)

        var lines: [(String, [NSAttributedString.Key: Any])] = [
            (status.device.name, nameAttrs),
            (detail, detailAttrs),
        ]
        if let componentsLine { lines.append((componentsLine, detailAttrs)) }

        let lineHeights: [CGFloat] = lines.map { ($0.1[.font] as! NSFont).pointSize + 5 }
        let blockHeight = lineHeights.reduce(0, +)
        var top = (bounds.height + blockHeight) / 2

        for (i, line) in lines.enumerated() {
            let h = lineHeights[i]
            let rect = NSRect(x: textX, y: top - h, width: textW, height: h)
            NSAttributedString(string: line.0, attributes: line.1).draw(in: rect)
            top -= h
        }
    }
}
