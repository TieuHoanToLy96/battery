import AppKit

/// Dòng kiểu menu trong popover: full-width, highlight khi hover, chữ trái,
/// (tuỳ chọn) giá trị + mũi tên bên phải. Hỗ trợ click action hoặc flyout
/// menu bên cạnh khi hover (mô phỏng submenu).
final class MenuRowView: NSView {

    private let title: String
    private let trailing: String?
    private let showsChevron: Bool
    private let onClick: (() -> Void)?
    private let flyout: (() -> NSMenu)?

    private var highlighted = false
    private var trackingArea: NSTrackingArea?
    private var flyoutShowing = false

    init(
        width: CGFloat,
        title: String,
        trailing: String? = nil,
        chevron: Bool = false,
        onClick: (() -> Void)? = nil,
        flyout: (() -> NSMenu)? = nil
    ) {
        self.title = title
        self.trailing = trailing
        self.showsChevron = chevron
        self.onClick = onClick
        self.flyout = flyout
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 28))
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: width).isActive = true
        heightAnchor.constraint(equalToConstant: 28).isActive = true
    }

    required init?(coder: NSCoder) { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func draw(_ dirtyRect: NSRect) {
        if highlighted {
            let bg = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 1), xRadius: 7, yRadius: 7)
            NSColor.white.withAlphaComponent(0.14).setFill()
            bg.fill()
        }

        let titleStr = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.labelColor,
        ])
        titleStr.draw(at: NSPoint(x: 12, y: (bounds.height - titleStr.size().height) / 2))
        let titleWidth = titleStr.size().width

        var rightX = bounds.maxX - 12
        if showsChevron {
            let chev = NSAttributedString(string: "›", attributes: [
                .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor,
            ])
            let size = chev.size()
            rightX -= size.width
            chev.draw(at: NSPoint(x: rightX, y: (bounds.height - size.height) / 2))
            rightX -= 6
        }
        if let trailing {
            // Giới hạn vùng trailing = từ sau tiêu đề tới rightX; dài thì "…".
            let para = NSMutableParagraphStyle()
            para.lineBreakMode = .byTruncatingTail
            para.alignment = .right
            let str = NSAttributedString(string: trailing, attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.labelColor.withAlphaComponent(0.82),
                .paragraphStyle: para,
            ])
            let maxWidth = max(0, rightX - (12 + titleWidth + 10))
            let h = str.size().height
            let rect = NSRect(x: rightX - maxWidth, y: (bounds.height - h) / 2, width: maxWidth, height: h)
            str.draw(in: rect)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        highlighted = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        highlighted = false
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if let flyout {
            showFlyout(flyout())
        } else {
            onClick?()
        }
    }

    private func showFlyout(_ menu: NSMenu) {
        flyoutShowing = true
        // Mở menu bên phải dòng, canh theo cạnh trên.
        let point = NSPoint(x: bounds.maxX - 4, y: bounds.maxY)
        menu.popUp(positioning: nil, at: point, in: self)
        flyoutShowing = false
        highlighted = false
        needsDisplay = true
    }
}
