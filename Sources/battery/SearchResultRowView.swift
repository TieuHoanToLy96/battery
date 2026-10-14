import AppKit
import BatteryKit

/// Một dòng kết quả tìm kiếm: thumbnail + tên + kênh, click để phát.
final class SearchResultRowView: NSView {

    private let result: YouTubeResult
    var onSelect: ((YouTubeResult) -> Void)?

    private let thumb = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let authorLabel = NSTextField(labelWithString: "")
    private var highlighted = false
    private var trackingArea: NSTrackingArea?

    init(result: YouTubeResult, width: CGFloat, image: NSImage? = nil) {
        self.result = result
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 50))
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: width).isActive = true
        heightAnchor.constraint(equalToConstant: 50).isActive = true
        build()
        if let image {
            thumb.image = image
        } else {
            loadThumbnail()
        }
    }

    required init?(coder: NSCoder) { nil }

    private func build() {
        thumb.translatesAutoresizingMaskIntoConstraints = false
        thumb.imageScaling = .scaleProportionallyUpOrDown
        thumb.wantsLayer = true
        thumb.layer?.cornerRadius = 5
        thumb.layer?.masksToBounds = true
        thumb.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor

        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 2
        titleLabel.cell?.wraps = true
        authorLabel.font = .systemFont(ofSize: 10)
        authorLabel.textColor = .labelColor.withAlphaComponent(0.6)
        authorLabel.lineBreakMode = .byTruncatingTail
        authorLabel.maximumNumberOfLines = 1
        titleLabel.stringValue = result.title
        authorLabel.stringValue = result.author

        let textStack = NSStackView(views: [titleLabel, authorLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(thumb)
        addSubview(textStack)
        NSLayoutConstraint.activate([
            thumb.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            thumb.centerYAnchor.constraint(equalTo: centerYAnchor),
            thumb.widthAnchor.constraint(equalToConstant: 60),
            thumb.heightAnchor.constraint(equalToConstant: 34),
            textStack.leadingAnchor.constraint(equalTo: thumb.trailingAnchor, constant: 10),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    private func loadThumbnail() {
        URLSession.shared.dataTask(with: result.thumbnailURL) { [weak self] data, _, _ in
            guard let data, let image = NSImage(data: data) else { return }
            DispatchQueue.main.async { self?.thumb.image = image }
        }.resume()
    }

    override func draw(_ dirtyRect: NSRect) {
        if highlighted {
            let bg = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 1), xRadius: 7, yRadius: 7)
            NSColor.white.withAlphaComponent(0.12).setFill()
            bg.fill()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { highlighted = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { highlighted = false; needsDisplay = true }
    override func mouseUp(with event: NSEvent) { onSelect?(result) }
}
