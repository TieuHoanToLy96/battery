import AppKit

/// Vẽ nền thẻ "liquid glass": nền mờ bo góc + bóng mềm + viền gradient chéo.
/// Dùng chung cho thẻ thiết bị và thẻ Now Playing.
enum GlassCard {

    static func draw(in bounds: NSRect, inset: CGFloat = 3, radius: CGFloat = 14) {
        let rect = bounds.insetBy(dx: inset, dy: inset)

        // Nền + bóng đổ mềm tạo chiều sâu.
        let fill = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
        shadow.shadowBlurRadius = 7
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.set()
        NSColor.white.withAlphaComponent(0.07).setFill()
        fill.fill()
        NSGraphicsContext.restoreGraphicsState()

        // Viền gradient chéo: sáng góc trên-trái → tắt dần xuống dưới-phải.
        let lineWidth: CGFloat = 1
        let ring = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        let inner = NSBezierPath(
            roundedRect: rect.insetBy(dx: lineWidth, dy: lineWidth),
            xRadius: radius - lineWidth, yRadius: radius - lineWidth
        )
        ring.append(inner.reversed)
        ring.windingRule = .evenOdd
        NSGraphicsContext.saveGraphicsState()
        ring.addClip()
        NSGradient(colors: [
            NSColor.white.withAlphaComponent(0.5),
            NSColor.white.withAlphaComponent(0.12),
            NSColor.white.withAlphaComponent(0.0),
        ])?.draw(in: rect, angle: -45)
        NSGraphicsContext.restoreGraphicsState()
    }
}
