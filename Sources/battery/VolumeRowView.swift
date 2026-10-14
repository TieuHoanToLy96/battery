import AppKit

/// Dòng chỉnh âm lượng hệ thống trong khu cài đặt: icon loa + thanh trắng.
final class VolumeRowView: NSView {

    private let icon = NSImageView()
    private let bar = SeekBarView()

    init(width: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 30))
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: width).isActive = true
        heightAnchor.constraint(equalToConstant: 30).isActive = true
        build()
    }

    required init?(coder: NSCoder) { nil }

    private func build() {
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.contentTintColor = .labelColor.withAlphaComponent(0.85)
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.onChange = { [weak self] value in self?.apply(Float(value)) }
        bar.onSeek = { [weak self] value in self?.apply(Float(value)) }

        addSubview(icon)
        addSubview(bar)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            bar.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            bar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            bar.centerYAnchor.constraint(equalTo: centerYAnchor),
            bar.heightAnchor.constraint(equalToConstant: 12),
        ])
        refresh()
    }

    /// Đồng bộ thanh với âm lượng hệ thống hiện tại.
    func refresh() {
        guard !bar.isDragging, let volume = SystemVolume.current() else { return }
        bar.setFraction(Double(volume))
        updateIcon(volume)
    }

    private func apply(_ value: Float) {
        SystemVolume.set(value)
        updateIcon(value)
    }

    private func updateIcon(_ level: Float) {
        let name: String
        if level <= 0.001 { name = "speaker.slash.fill" }
        else if level < 0.33 { name = "speaker.fill" }
        else if level < 0.66 { name = "speaker.wave.1.fill" }
        else { name = "speaker.wave.2.fill" }
        icon.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .regular))
    }
}
