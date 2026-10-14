import AppKit

/// Label tự chạy chữ (marquee) khi nội dung dài hơn bề ngang.
final class MarqueeLabel: NSView {

    var stringValue: String = "" {
        didSet { if stringValue != oldValue { resetScroll() }; needsDisplay = true }
    }
    var font: NSFont = .systemFont(ofSize: 13, weight: .semibold)
    var textColor: NSColor = .labelColor

    private var offset: CGFloat = 0
    private var pauseTicks = 0
    private var timer: Timer?
    private let gap: CGFloat = 46
    private let speed: CGFloat = 0.6

    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 18) }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { startTimer() } else { timer?.invalidate(); timer = nil }
    }

    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.02, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func resetScroll() {
        offset = 0
        pauseTicks = 70   // dừng ~1.4s ở đầu trước khi chạy
    }

    private func attributed() -> NSAttributedString {
        NSAttributedString(string: stringValue, attributes: [.font: font, .foregroundColor: textColor])
    }

    private func tick() {
        guard window != nil else { return }
        let textWidth = attributed().size().width
        guard textWidth > bounds.width else {
            if offset != 0 { offset = 0; needsDisplay = true }
            return
        }
        if pauseTicks > 0 { pauseTicks -= 1; return }
        offset -= speed
        if offset <= -(textWidth + gap) { offset += textWidth + gap }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let str = attributed()
        let size = str.size()
        let y = (bounds.height - size.height) / 2

        // Chỉ vẽ trong phạm vi của label (không đè lên view khác).
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: bounds).addClip()
        if size.width <= bounds.width {
            str.draw(at: NSPoint(x: 0, y: y))
        } else {
            // Vẽ 2 bản liền nhau để cuộn liền mạch.
            str.draw(at: NSPoint(x: offset, y: y))
            str.draw(at: NSPoint(x: offset + size.width + gap, y: y))
        }
        NSGraphicsContext.restoreGraphicsState()
    }
}
