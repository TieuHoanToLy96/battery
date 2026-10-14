import AppKit

/// Thẻ glass bọc một nhóm dòng (vd khu cài đặt) — nền giống thẻ thiết bị.
final class GlassCardContainer: NSView {

    init(width: CGFloat, rows: [NSView]) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 10))
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: width).isActive = true

        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 1
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 9),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -9),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        GlassCard.draw(in: bounds)
    }
}
