import AppKit

/// Card "đang phát": artwork + tên/nghệ sĩ + thanh tua + prev/pause/next.
final class NowPlayingView: NSView {

    var onPrevious: (() -> Void)?
    var onTogglePlay: (() -> Void)?
    var onNext: (() -> Void)?
    var onSeek: ((Double) -> Void)?

    private let artworkView = NSImageView()
    private let backButton = NSButton()
    private let forwardButton = NSButton()
    private let loopButton = NSButton()
    private var skipSeconds = 10
    var onToggleLoop: (() -> Void)?

    private let titleMarquee = MarqueeLabel()
    private let artistLabel = NSTextField(labelWithString: "")
    private let seekBar = SeekBarView()
    private let elapsedLabel = NSTextField(labelWithString: "0:00")
    private let durationLabel = NSTextField(labelWithString: "0:00")
    private let playButton = NSButton()
    private let spinner = NSProgressIndicator()

    private var currentTitle = ""
    private var missCount = 0
    private var hasContent = false
    private var loadingFromTitle: String?
    private var loadingTimeout: DispatchWorkItem?

    // Mốc để tính vị trí phát sống giữa các lần poll.
    private var baseElapsed: Double = 0
    private var baseTimestamp = Date()
    private var duration: Double = 0
    private var playing = false
    private var tickTimer: Timer?

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: DeviceRowView.cardWidth, height: 138))
        build()
        startTicking()
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        GlassCard.draw(in: bounds)
    }

    private func build() {
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: DeviceRowView.cardWidth).isActive = true
        heightAnchor.constraint(equalToConstant: 138).isActive = true

        artworkView.translatesAutoresizingMaskIntoConstraints = false
        artworkView.imageScaling = .scaleProportionallyUpOrDown
        artworkView.wantsLayer = true
        artworkView.layer?.cornerRadius = 8
        artworkView.layer?.masksToBounds = true
        artworkView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor

        titleMarquee.font = .systemFont(ofSize: 13, weight: .semibold)
        titleMarquee.textColor = .labelColor
        titleMarquee.translatesAutoresizingMaskIntoConstraints = false
        titleMarquee.heightAnchor.constraint(equalToConstant: 18).isActive = true
        titleMarquee.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleMarquee.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        artistLabel.font = .systemFont(ofSize: 11)
        artistLabel.textColor = .labelColor.withAlphaComponent(0.7)
        artistLabel.lineBreakMode = .byTruncatingTail
        artistLabel.maximumNumberOfLines = 1

        let textStack = NSStackView(views: [titleMarquee, artistLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        // Chiều rộng = phần còn lại bên phải artwork (để chữ chạy full vùng đó).
        let titleWidth = DeviceRowView.cardWidth - 28 - 46 - 10
        titleMarquee.widthAnchor.constraint(equalToConstant: titleWidth).isActive = true
        artistLabel.widthAnchor.constraint(lessThanOrEqualToConstant: titleWidth).isActive = true

        let topRow = NSStackView(views: [artworkView, textStack])
        topRow.orientation = .horizontal
        topRow.alignment = .centerY
        topRow.spacing = 10

        seekBar.translatesAutoresizingMaskIntoConstraints = false
        seekBar.heightAnchor.constraint(equalToConstant: 12).isActive = true
        seekBar.setContentHuggingPriority(.defaultLow, for: .horizontal)
        seekBar.onSeek = { [weak self] fraction in
            guard let self else { return }
            let seconds = fraction * self.duration
            self.onSeek?(seconds)
            // Lạc quan: tiếp tục chạy từ vị trí mới tới lần poll kế.
            self.baseElapsed = seconds
            self.baseTimestamp = Date()
        }
        [elapsedLabel, durationLabel].forEach {
            $0.font = .systemFont(ofSize: 9)
            $0.textColor = .labelColor.withAlphaComponent(0.6)
        }
        let sliderRow = NSStackView(views: [elapsedLabel, seekBar, durationLabel])
        sliderRow.orientation = .horizontal
        sliderRow.alignment = .centerY
        sliderRow.spacing = 6

        configureIconButton(backButton, symbol: "gobackward.10", #selector(back10Tapped))
        let prev = iconButton("backward.fill", #selector(prevTapped))
        configurePlayButton()
        let next = iconButton("forward.fill", #selector(nextTapped))
        configureIconButton(forwardButton, symbol: "goforward.10", #selector(forward10Tapped))
        configureIconButton(loopButton, symbol: "repeat", #selector(loopTapped))

        // Transport ở GIỮA, nút loop neo bên TRÁI độc lập.
        let transport = NSStackView(views: [backButton, prev, playButton, next, forwardButton])
        transport.orientation = .horizontal
        transport.alignment = .centerY
        transport.spacing = 18
        transport.translatesAutoresizingMaskIntoConstraints = false
        loopButton.translatesAutoresizingMaskIntoConstraints = false

        let controls = NSView()
        controls.translatesAutoresizingMaskIntoConstraints = false
        controls.addSubview(transport)
        controls.addSubview(loopButton)
        NSLayoutConstraint.activate([
            controls.widthAnchor.constraint(equalToConstant: DeviceRowView.cardWidth - 28),
            transport.topAnchor.constraint(equalTo: controls.topAnchor),
            transport.bottomAnchor.constraint(equalTo: controls.bottomAnchor),
            transport.centerXAnchor.constraint(equalTo: controls.centerXAnchor),
            loopButton.leadingAnchor.constraint(equalTo: controls.leadingAnchor),
            loopButton.centerYAnchor.constraint(equalTo: transport.centerYAnchor),
        ])

        let main = NSStackView(views: [topRow, sliderRow, controls])
        main.orientation = .vertical
        main.alignment = .centerX
        main.spacing = 10
        main.translatesAutoresizingMaskIntoConstraints = false
        addSubview(main)

        NSLayoutConstraint.activate([
            artworkView.widthAnchor.constraint(equalToConstant: 46),
            artworkView.heightAnchor.constraint(equalToConstant: 46),
            topRow.widthAnchor.constraint(equalToConstant: DeviceRowView.cardWidth - 28),
            sliderRow.widthAnchor.constraint(equalToConstant: DeviceRowView.cardWidth - 28),
            main.centerYAnchor.constraint(equalTo: centerYAnchor),
            main.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])

        // Spinner loading phủ giữa artwork (ẩn khi dừng).
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: artworkView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: artworkView.centerYAnchor),
        ])
    }

    private func startLoading() {
        loadingFromTitle = currentTitle
        spinner.startAnimation(nil)
        artworkView.animator().alphaValue = 0.35

        loadingTimeout?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.stopLoading() }
        loadingTimeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    private func stopLoading() {
        loadingFromTitle = nil
        loadingTimeout?.cancel()
        loadingTimeout = nil
        spinner.stopAnimation(nil)
        artworkView.animator().alphaValue = 1.0
    }

    private func configurePlayButton() {
        playButton.bezelStyle = .regularSquare
        playButton.isBordered = false
        playButton.imagePosition = .imageOnly
        playButton.contentTintColor = .labelColor
        playButton.target = self
        playButton.action = #selector(playTapped)
        setPlayImage(playing: false)
    }

    private func iconButton(_ symbol: String, _ action: Selector) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.contentTintColor = .labelColor
        button.target = self
        button.action = action
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .medium))
        return button
    }

    private func setPlayImage(playing: Bool) {
        playButton.image = NSImage(systemSymbolName: playing ? "pause.fill" : "play.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 18, weight: .medium))
    }

    // MARK: - Update

    func update(_ np: NowPlaying?) {
        guard let np else {
            missCount += 1
            if !hasContent || missCount >= 3 {
                isHidden = true
                hasContent = false
            }
            return
        }
        missCount = 0
        hasContent = true
        isHidden = false

        // Đang loading và bài đã đổi => bài mới về, tắt spinner.
        if let from = loadingFromTitle, np.title != from {
            stopLoading()
        }

        if np.title != currentTitle {
            currentTitle = np.title
            titleMarquee.stringValue = np.title
            artistLabel.stringValue = np.artist
            artistLabel.isHidden = np.artist.isEmpty
            if let data = np.artwork, let image = NSImage(data: data) {
                artworkView.image = image
            } else {
                artworkView.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
            }
        }

        baseElapsed = np.elapsed
        baseTimestamp = np.timestamp ?? Date()
        duration = np.duration
        playing = np.playing
        durationLabel.stringValue = Self.timeString(duration)
        setPlayImage(playing: np.playing)
        refreshPosition()
    }

    private func startTicking() {
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.refreshPosition()
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    /// Tính vị trí phát sống = elapsed + (bây giờ − timestamp) khi đang phát.
    private func refreshPosition() {
        guard window != nil, hasContent, !isHidden else { return }
        var live = baseElapsed
        if playing { live += Date().timeIntervalSince(baseTimestamp) }
        live = max(0, min(duration, live))
        elapsedLabel.stringValue = Self.timeString(live)
        seekBar.setFraction(duration > 0 ? live / duration : 0)
    }

    // MARK: - Bước tua

    /// Đặt bước tua (giây) + cập nhật icon nút.
    func applySkip(seconds: Int) {
        skipSeconds = seconds
        backButton.image = skipImage("gobackward", seconds)
        forwardButton.image = skipImage("goforward", seconds)
    }

    /// Icon có số (vd gobackward.30) nếu SF Symbol hỗ trợ, không thì icon chung.
    private func skipImage(_ base: String, _ seconds: Int) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        return (NSImage(systemSymbolName: "\(base).\(seconds)", accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: base, accessibilityDescription: nil))?
            .withSymbolConfiguration(config)
    }

    private func configureIconButton(_ button: NSButton, symbol: String, _ action: Selector) {
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.contentTintColor = .labelColor
        button.target = self
        button.action = action
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .medium))
    }

    private static func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: - Actions

    @objc private func prevTapped() { startLoading(); onPrevious?() }
    @objc private func playTapped() { onTogglePlay?() }
    @objc private func nextTapped() { startLoading(); onNext?() }

    @objc private func back10Tapped() { skip(by: -Double(skipSeconds)) }
    @objc private func forward10Tapped() { skip(by: Double(skipSeconds)) }
    @objc private func loopTapped() { onToggleLoop?() }

    /// Hiển thị trạng thái loop (tô xanh khi bật).
    func setLoopActive(_ on: Bool) {
        loopButton.contentTintColor = on ? .systemGreen : .labelColor
    }

    private func currentLive() -> Double {
        var live = baseElapsed
        if playing { live += Date().timeIntervalSince(baseTimestamp) }
        return max(0, min(duration, live))
    }

    private func skip(by seconds: Double) {
        let target = max(0, min(duration, currentLive() + seconds))
        onSeek?(target)
        baseElapsed = target
        baseTimestamp = Date()
        refreshPosition()
    }

}
