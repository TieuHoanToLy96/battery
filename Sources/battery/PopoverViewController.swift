import AppKit
import QuartzCore
import CoreAudio
import BatteryKit

/// Nền "liquid glass" mô phỏng: blur tối (hudWindow) + lớp sheen sáng ở đỉnh.
final class GlassEffectView: NSVisualEffectView {

    private let sheen = CAGradientLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true

        // Ánh sáng chuyển từ đỉnh (sáng) xuống giữa (trong), tạo cảm giác kính.
        sheen.colors = [
            NSColor.white.withAlphaComponent(0.14).cgColor,
            NSColor.white.withAlphaComponent(0.02).cgColor,
            NSColor.clear.cgColor,
        ]
        sheen.locations = [0.0, 0.35, 1.0]
        sheen.startPoint = CGPoint(x: 0.5, y: 1.0)   // đỉnh
        sheen.endPoint = CGPoint(x: 0.5, y: 0.0)     // đáy
        layer?.addSublayer(sheen)
    }

    override func layout() {
        super.layout()
        sheen.frame = bounds
    }
}

/// Nội dung popover kiểu glass: nền blur + danh sách thẻ thiết bị + điều khiển.
final class PopoverViewController: NSViewController {

    var onThresholdChange: ((Int) -> Void)?
    var onRefresh: (() -> Void)?
    var onQuit: (() -> Void)?

    private let stack = NSStackView()
    private var contentWidth: CGFloat { DeviceRowView.cardWidth + 20 }

    private var lastStatuses: [BatteryMonitor.DeviceStatus] = []
    private var lastThreshold = Preferences.defaultThreshold

    private let searchField = NSSearchField()
    private let searchSpinner = NSProgressIndicator()
    private var lastResults: [YouTubeResult] = []
    private var lastImages: [String: NSImage] = [:]

    private let preferences = Preferences()
    private let nowPlaying = NowPlayingController()
    private let nowPlayingView = NowPlayingView()
    private lazy var nowPlayingTitle = sectionTitle("Đang phát")
    private static let settingsRowWidth = DeviceRowView.cardWidth - 26
    private let volumeRow = VolumeRowView(width: DeviceRowView.cardWidth - 26)
    private var pollTimer: Timer?

    override func loadView() {
        let effect = GlassEffectView()

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: effect.topAnchor),
            stack.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            effect.widthAnchor.constraint(equalToConstant: contentWidth),
        ])
        view = effect
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        searchField.placeholderString = "Tìm trên YouTube…"
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.widthAnchor.constraint(equalToConstant: DeviceRowView.cardWidth).isActive = true
        searchField.heightAnchor.constraint(equalToConstant: 32).isActive = true
        searchField.controlSize = .large
        searchField.font = .systemFont(ofSize: 14)
        searchField.focusRingType = .none
        searchField.sendsSearchStringImmediately = false
        searchField.sendsWholeSearchString = true
        searchField.target = self
        searchField.action = #selector(performSearch)

        searchSpinner.style = .spinning
        searchSpinner.controlSize = .small
        searchSpinner.isDisplayedWhenStopped = false
        searchSpinner.translatesAutoresizingMaskIntoConstraints = false
        searchField.addSubview(searchSpinner)
        NSLayoutConstraint.activate([
            searchSpinner.trailingAnchor.constraint(equalTo: searchField.trailingAnchor, constant: -8),
            searchSpinner.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
        ])

        nowPlayingView.onPrevious = { [weak self] in
            if !ChromeController.youtubePrevious() { self?.nowPlaying.previous() }
            self?.refreshNowPlayingSoon()
        }
        nowPlayingView.onTogglePlay = { [weak self] in self?.nowPlaying.togglePlayPause(); self?.refreshNowPlayingSoon() }
        nowPlayingView.onNext = { [weak self] in
            if !ChromeController.youtubeNext() { self?.nowPlaying.next() }
            self?.refreshNowPlayingSoon()
        }
        nowPlayingView.onSeek = { [weak self] seconds in self?.nowPlaying.seek(seconds) }
        nowPlayingView.onToggleLoop = { [weak self] in
            guard let self else { return }
            self.preferences.loopEnabled.toggle()
            ChromeController.setLoop(self.preferences.loopEnabled)
            self.nowPlayingView.setLoopActive(self.preferences.loopEnabled)
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        // Khôi phục từ khoá tìm kiếm gần nhất.
        if searchField.stringValue.isEmpty {
            searchField.stringValue = preferences.lastSearchQuery
        }
        pollNowPlaying()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollNowPlaying()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // Mở lại popover: hiện lại danh sách kết quả gần nhất (nếu có).
        if !lastResults.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self, self.view.window != nil, !self.lastResults.isEmpty else { return }
                self.presentResultsMenu(self.lastResults, images: self.lastImages)
            }
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func pollNowPlaying() {
        nowPlayingView.applySkip(seconds: preferences.skipSeconds)
        nowPlayingView.setLoopActive(preferences.loopEnabled)
        nowPlaying.fetch { [weak self] np in
            guard let self else { return }
            self.nowPlayingView.update(np)
            self.nowPlayingTitle.isHidden = self.nowPlayingView.isHidden
        }
        volumeRow.refresh()
    }

    private func refreshNowPlayingSoon() {
        for delay in [0.3, 0.9, 1.6] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.pollNowPlaying() }
        }
    }

    /// Dựng lại nội dung popover.
    func render(statuses: [BatteryMonitor.DeviceStatus], threshold: Int) {
        lastStatuses = statuses
        lastThreshold = threshold
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // ─ Tìm kiếm YouTube ─ (kết quả hiện flyout bên cạnh)
        stack.addArrangedSubview(searchField)

        // ─ Đang phát ─
        if nowPlaying.isAvailable {
            stack.addArrangedSubview(nowPlayingTitle)
            stack.addArrangedSubview(nowPlayingView)
            nowPlayingTitle.isHidden = nowPlayingView.isHidden
        }

        // ─ Thiết bị Bluetooth ─
        stack.addArrangedSubview(sectionTitle("Thiết bị Bluetooth"))
        let withBattery = statuses.filter { $0.device.hasBattery }
        if withBattery.isEmpty {
            stack.addArrangedSubview(mutedLabel("Không có thiết bị Bluetooth"))
        } else {
            let activeAudio = AudioActivity.activeDeviceNames()
            for status in withBattery {
                let active = AudioActivity.isActive(deviceName: status.device.name, among: activeAudio)
                stack.addArrangedSubview(DeviceRowView(status: status, threshold: threshold, isActive: active))
            }
        }

        // ─ Cài đặt (trong thẻ glass) ─
        stack.addArrangedSubview(sectionTitle("Cài đặt"))
        stack.addArrangedSubview(GlassCardContainer(width: DeviceRowView.cardWidth, rows: settingsRows(threshold: threshold)))
    }

    /// Các dòng trong thẻ Cài đặt.
    private func settingsRows(threshold: Int) -> [NSView] {
        let width = Self.settingsRowWidth
        var rows: [NSView] = []

        let outputs = AudioActivity.outputDevices()
        if !outputs.isEmpty {
            let currentID = AudioActivity.defaultOutputID()
            let currentName = outputs.first { $0.id == currentID }?.name ?? "—"
            rows.append(MenuRowView(
                width: width, title: "Đầu ra âm thanh", trailing: currentName, chevron: true,
                flyout: { [weak self] in self?.outputMenu(outputs, currentID: currentID) ?? NSMenu() }
            ))
        }

        volumeRow.refresh()
        rows.append(volumeRow)

        rows.append(MenuRowView(
            width: width, title: "Ngưỡng cảnh báo", trailing: "\(threshold)%", chevron: true,
            flyout: { [weak self] in self?.thresholdMenu(current: threshold) ?? NSMenu() }
        ))

        // Bước tua nhanh/lùi.
        rows.append(MenuRowView(
            width: width, title: "Bước tua",
            trailing: Self.skipLabel(preferences.skipSeconds), chevron: true,
            flyout: { [weak self] in self?.skipMenu() ?? NSMenu() }
        ))

        // Equalizer (YouTube/Chrome) — chọn preset.
        rows.append(MenuRowView(
            width: width, title: "Equalizer",
            trailing: EQ.name(for: preferences.eqGains), chevron: true,
            flyout: { [weak self] in self?.eqMenu() ?? NSMenu() }
        ))

        rows.append(MenuRowView(width: width, title: "Làm mới", onClick: { [weak self] in self?.onRefresh?() }))
        rows.append(MenuRowView(width: width, title: "Thoát", onClick: { [weak self] in self?.onQuit?() }))
        return rows
    }

    private static func skipLabel(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds)s" : "\(seconds / 60) phút"
    }

    private func skipMenu() -> NSMenu {
        let menu = NSMenu()
        for seconds in Preferences.availableSkipSteps {
            let item = NSMenuItem(title: Self.skipLabel(seconds), action: #selector(skipPicked(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = seconds
            item.state = (seconds == preferences.skipSeconds) ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    @objc private func skipPicked(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? Int else { return }
        preferences.skipSeconds = seconds
        nowPlayingView.applySkip(seconds: seconds)
        render(statuses: lastStatuses, threshold: lastThreshold)
    }

    private func eqMenu() -> NSMenu {
        let menu = NSMenu()
        for preset in EQ.presets {
            let item = NSMenuItem(title: preset.name, action: #selector(eqPicked(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset.name
            item.state = (preset.gains == preferences.eqGains) ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    @objc private func eqPicked(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        let preset = EQ.preset(named: name)
        preferences.eqGains = preset.gains
        ChromeController.applyEQ(gains: preset.gains, freqs: EQ.bands)
        render(statuses: lastStatuses, threshold: lastThreshold)
    }


    /// Menu flyout chọn ngưỡng (có dấu tích ở giá trị hiện tại).
    private func thresholdMenu(current: Int) -> NSMenu {
        let menu = NSMenu()
        for value in Preferences.availableThresholds {
            let item = NSMenuItem(title: "\(value)%", action: #selector(thresholdPicked(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            item.state = (value == current) ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: 11, weight: .semibold)
        field.textColor = .secondaryLabelColor
        return field
    }

    private func mutedLabel(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: 12)
        field.textColor = .secondaryLabelColor
        return field
    }

    private func divider() -> NSView {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        v.widthAnchor.constraint(equalToConstant: DeviceRowView.cardWidth).isActive = true
        return v
    }

    /// Menu flyout chọn đầu ra âm thanh (dấu tích ở thiết bị đang dùng).
    private func outputMenu(_ devices: [AudioActivity.OutputDevice], currentID: AudioObjectID?) -> NSMenu {
        let menu = NSMenu()
        for device in devices {
            let item = NSMenuItem(title: device.name, action: #selector(outputPicked(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = NSNumber(value: device.id)
            item.state = (device.id == currentID) ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    // MARK: - Tìm kiếm

    @objc private func performSearch() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        preferences.lastSearchQuery = query
        searchSpinner.startAnimation(nil)
        YouTubeSearch.search(query) { [weak self] results in
            self?.showResultsMenu(Array(results.prefix(20)))
        }
    }

    /// Hiện kết quả dạng flyout menu bên cạnh ô search (như flyout ngưỡng).
    /// Tải sẵn thumbnail trước khi bung (NSMenu modal không chạy callback tải ảnh).
    private func showResultsMenu(_ results: [YouTubeResult]) {
        guard !results.isEmpty else { searchSpinner.stopAnimation(nil); return }
        let group = DispatchGroup()
        let lock = NSLock()
        var images: [String: NSImage] = [:]
        for result in results {
            group.enter()
            URLSession.shared.dataTask(with: result.thumbnailURL) { data, _, _ in
                if let data, let image = NSImage(data: data) {
                    lock.lock(); images[result.videoId] = image; lock.unlock()
                }
                group.leave()
            }.resume()
        }
        group.notify(queue: .main) { [weak self] in
            self?.presentResultsMenu(results, images: images)
        }
    }

    private func presentResultsMenu(_ results: [YouTubeResult], images: [String: NSImage]) {
        searchSpinner.stopAnimation(nil)
        lastResults = results
        lastImages = images
        let menu = NSMenu()
        for result in results {
            let row = SearchResultRowView(result: result, width: 340, image: images[result.videoId])
            row.onSelect = { [weak self, weak menu] selected in
                menu?.cancelTracking()
                // Mở kèm hàng đợi Mix (&list=RD<id>) để có autoplay → next/prev
                // hoạt động (video đơn lẻ mở trực tiếp không có hàng đợi).
                let playURL = URL(string: "https://www.youtube.com/watch?v=\(selected.videoId)&list=RD\(selected.videoId)")
                    ?? selected.watchURL
                if !ChromeController.playInExistingYouTubeTab(playURL) {
                    NSWorkspace.shared.open(playURL)
                }
                // Giữ nguyên từ khoá để lần mở sau vẫn thấy.
            }
            let item = NSMenuItem()
            item.view = row
            menu.addItem(item)
        }
        let point = NSPoint(x: searchField.bounds.maxX + 4, y: searchField.bounds.maxY)
        menu.popUp(positioning: nil, at: point, in: searchField)
    }

    // MARK: - Actions

    @objc private func thresholdPicked(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Int else { return }
        onThresholdChange?(value)
    }

    @objc private func outputPicked(_ sender: NSMenuItem) {
        guard let number = sender.representedObject as? NSNumber else { return }
        AudioActivity.setDefaultOutput(AudioObjectID(number.uint32Value))
        render(statuses: lastStatuses, threshold: lastThreshold)
    }
}
