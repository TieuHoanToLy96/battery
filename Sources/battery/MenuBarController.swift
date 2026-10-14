import AppKit
import BatteryKit

/// NSImageView cho click xuyên qua (để button menu bar vẫn nhận click).
private final class PassthroughImageView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// Quản lý NSStatusItem + popover kiểu glass hiển thị danh sách thiết bị.
final class MenuBarController: NSObject {

    private let statusItem: NSStatusItem
    private let monitor: BatteryMonitor
    private let preferences: Preferences
    private let popover = NSPopover()
    private let contentVC = PopoverViewController()

    private let nowPlaying = NowPlayingController()
    private let waveformView = PassthroughImageView()
    private var musicPlaying = false
    private var musicTimer: Timer?
    private var lowStatuses: [BatteryMonitor.DeviceStatus] = []

    init(monitor: BatteryMonitor, preferences: Preferences) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.monitor = monitor
        self.preferences = preferences
        super.init()

        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)

        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = contentVC
        // Glass tối đồng nhất, chữ sáng.
        popover.appearance = NSAppearance(named: .vibrantDark)

        contentVC.onThresholdChange = { [weak self] value in
            guard let self else { return }
            self.preferences.threshold = value
            self.contentVC.render(statuses: self.monitor.statuses, threshold: value)
            self.monitor.pollNow()
        }
        contentVC.onRefresh = { [weak self] in self?.monitor.pollNow() }
        contentVC.onQuit = { NSApp.terminate(nil) }

        monitor.onUpdate = { [weak self] statuses in
            self?.render(statuses)
        }

        waveformView.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "đang phát nhạc")
        waveformView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        waveformView.contentTintColor = .labelColor
        waveformView.isHidden = true
    }

    func install() {
        render(monitor.statuses)
        startMusicMonitor()
    }

    // MARK: - Waveform khi có nhạc

    private func startMusicMonitor() {
        guard nowPlaying.isAvailable else { return }
        checkMusic()
        let timer = Timer(timeInterval: 4, repeats: true) { [weak self] _ in self?.checkMusic() }
        RunLoop.main.add(timer, forMode: .common)
        musicTimer = timer
    }

    private func checkMusic() {
        nowPlaying.fetch { [weak self] np in
            guard let self else { return }
            self.setMusicPlaying(np?.playing == true)
            self.reapplyEQ(np)
            self.reapplyLoop(np)
        }
    }

    /// Giữ loop bật khi YouTube tải lại/đổi bài.
    private func reapplyLoop(_ np: NowPlaying?) {
        guard preferences.loopEnabled, let np, np.app == "com.google.Chrome", np.playing else { return }
        ChromeController.setLoop(true)
    }

    /// Áp lại EQ mỗi chu kỳ để giữ hiệu lực khi YouTube tải lại/điều hướng.
    private func reapplyEQ(_ np: NowPlaying?) {
        guard !preferences.eqIsFlat, let np, np.app == "com.google.Chrome", np.playing else { return }
        ChromeController.applyEQ(gains: preferences.eqGains, freqs: EQ.bands)
    }

    private func setMusicPlaying(_ playing: Bool) {
        guard playing != musicPlaying else { return }
        musicPlaying = playing
        refreshStatusItem()
    }

    private func setWaveformVisible(_ visible: Bool) {
        guard let button = statusItem.button else { return }
        if visible {
            if waveformView.superview == nil {
                waveformView.translatesAutoresizingMaskIntoConstraints = false
                button.addSubview(waveformView)
                NSLayoutConstraint.activate([
                    waveformView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                    waveformView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                ])
            }
            waveformView.isHidden = false
            if #available(macOS 14.0, *) {
                waveformView.addSymbolEffect(.variableColor.iterative.reversing, options: .repeating)
            }
        } else {
            if #available(macOS 14.0, *) {
                waveformView.removeSymbolEffect(ofType: .variableColor)
            }
            waveformView.isHidden = true
        }
    }

    // MARK: - Render

    private func render(_ statuses: [BatteryMonitor.DeviceStatus]) {
        updateButton(statuses)
        if popover.isShown {
            contentVC.render(statuses: statuses, threshold: preferences.threshold)
        }
    }

    private func updateButton(_ statuses: [BatteryMonitor.DeviceStatus]) {
        lowStatuses = statuses.filter { $0.isLow && !$0.isStale }
        refreshStatusItem()
    }

    /// Quyết định icon menu bar theo ưu tiên: pin thấp > đang phát nhạc > bình thường.
    private func refreshStatusItem() {
        guard let button = statusItem.button else { return }

        if let first = lowStatuses.first {
            // Cảnh báo pin thấp — luôn ưu tiên (kể cả khi đang phát nhạc).
            setWaveformVisible(false)
            statusItem.length = NSStatusItem.variableLength
            button.image = nil
            button.contentTintColor = nil

            // Nhúng icon đỏ inline + căn giữa theo chiều cao chữ.
            let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
                .applying(.init(paletteColors: [.systemRed]))
            let attachment = NSTextAttachment()
            attachment.image = NSImage(systemSymbolName: "battery.25", accessibilityDescription: "pin thấp")?
                .withSymbolConfiguration(config)
            if let size = attachment.image?.size {
                attachment.bounds = CGRect(x: 0, y: (font.capHeight - size.height) / 2, width: size.width, height: size.height)
            }
            let title = NSMutableAttributedString(attachment: attachment)
            if let pct = first.device.percent {
                title.append(NSAttributedString(
                    string: " \(first.device.name) \(pct)%",
                    attributes: [.foregroundColor: NSColor.labelColor, .font: font]
                ))
            }
            button.attributedTitle = title
        } else if musicPlaying {
            // Đang phát nhạc, không có pin thấp → waveform.
            button.title = ""
            button.image = nil
            statusItem.length = 30
            setWaveformVisible(true)
        } else {
            // Bình thường: ảnh template sáng theo menu bar.
            setWaveformVisible(false)
            statusItem.length = NSStatusItem.variableLength
            let image = NSImage(systemSymbolName: "battery.100", accessibilityDescription: "battery")
            image?.isTemplate = true
            button.image = image
            button.contentTintColor = nil
            button.title = ""
        }
    }

    // MARK: - Actions

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            contentVC.render(statuses: monitor.statuses, threshold: preferences.threshold)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
