import AppKit

/// Thanh tua tự vẽ (màu trắng): track mờ + phần đã chạy trắng + núm kéo.
/// Click/kéo để tua.
final class SeekBarView: NSView {

    /// Gọi khi thả chuột với vị trí mới (fraction 0..1).
    var onSeek: ((Double) -> Void)?
    /// Gọi liên tục khi kéo (dùng cho âm lượng live). nil = bỏ qua.
    var onChange: ((Double) -> Void)?

    private var fraction: CGFloat = 0
    private(set) var isDragging = false

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 12)
    }

    /// Cập nhật vị trí từ ngoài (bỏ qua khi đang kéo).
    func setFraction(_ value: Double) {
        guard !isDragging else { return }
        fraction = CGFloat(max(0, min(1, value)))
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let midY = bounds.midY
        let trackH: CGFloat = 3
        let radius = trackH / 2

        let trackRect = NSRect(x: 0, y: midY - trackH / 2, width: bounds.width, height: trackH)
        NSColor.white.withAlphaComponent(0.2).setFill()
        NSBezierPath(roundedRect: trackRect, xRadius: radius, yRadius: radius).fill()

        let fillW = max(0, min(bounds.width, bounds.width * fraction))
        if fillW > 0 {
            let fillRect = NSRect(x: 0, y: midY - trackH / 2, width: fillW, height: trackH)
            NSColor.white.withAlphaComponent(0.95).setFill()
            NSBezierPath(roundedRect: fillRect, xRadius: radius, yRadius: radius).fill()
        }

        // Núm trắng.
        let knobR: CGFloat = 5
        let kx = max(knobR, min(bounds.width - knobR, fillW))
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: kx - knobR, y: midY - knobR, width: knobR * 2, height: knobR * 2)).fill()
    }

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        updateFraction(event)
    }

    override func mouseDragged(with event: NSEvent) {
        updateFraction(event)
    }

    override func mouseUp(with event: NSEvent) {
        updateFraction(event)
        isDragging = false
        onSeek?(Double(fraction))
    }

    private func updateFraction(_ event: NSEvent) {
        let x = convert(event.locationInWindow, from: nil).x
        fraction = max(0, min(1, bounds.width > 0 ? x / bounds.width : 0))
        needsDisplay = true
        onChange?(Double(fraction))
    }
}
