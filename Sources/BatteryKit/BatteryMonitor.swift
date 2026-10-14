import Foundation

/// Điều phối: định kỳ đọc thiết bị, ghi lịch sử, tính ước lượng, và
/// phát hiện thiết bị chuyển xuống dưới ngưỡng để cảnh báo (edge-trigger).
public final class BatteryMonitor {

    /// Trạng thái một thiết bị để UI hiển thị.
    public struct DeviceStatus: Equatable {
        public let device: BluetoothDevice
        public let estimate: UsageEstimator.Estimate
        public let isLow: Bool
        /// true nếu % hiển thị là giá trị cuối cùng đã biết (thiết bị tạm
        /// ngừng báo pin, vd K380 giữa các lần kết nối), không phải đọc mới.
        public let isStale: Bool
        /// Thời điểm của giá trị pin cuối cùng khi `isStale`.
        public let lastUpdated: Date?

        public init(
            device: BluetoothDevice,
            estimate: UsageEstimator.Estimate,
            isLow: Bool,
            isStale: Bool = false,
            lastUpdated: Date? = nil
        ) {
            self.device = device
            self.estimate = estimate
            self.isLow = isLow
            self.isStale = isStale
            self.lastUpdated = lastUpdated
        }
    }

    /// Gọi trên main thread mỗi khi có dữ liệu mới.
    public var onUpdate: (([DeviceStatus]) -> Void)?

    private let reader: BatteryDeviceReading
    private let store: UsageHistoryStore
    private let estimator: UsageEstimator
    private let preferences: Preferences
    private let notifier: NotificationManager
    private let interval: TimeInterval
    private let now: () -> Date

    private let workQueue = DispatchQueue(label: "BatteryMonitor.work")
    private var timer: Timer?
    private var lowDeviceIds: Set<String> = []
    private let connectionObserver: BluetoothConnectionObserver?

    /// Khoảng trễ (giây) để poll lại sau khi có thiết bị kết nối — pin
    /// thường chỉ xuất hiện một lúc sau sự kiện kết nối.
    private static let connectPollDelays: [TimeInterval] = [1, 3, 7]

    public private(set) var statuses: [DeviceStatus] = []

    public init(
        reader: BatteryDeviceReading = CompositeBatteryReader([
            IOBluetoothFrameworkReader(),
            IORegistryBatteryReader(),
            BluetoothBatteryReader(),
        ]),
        store: UsageHistoryStore = UsageHistoryStore(),
        estimator: UsageEstimator = UsageEstimator(),
        preferences: Preferences = Preferences(),
        notifier: NotificationManager = NotificationManager(),
        connectionObserver: BluetoothConnectionObserver? = BluetoothConnectionObserver(),
        interval: TimeInterval = 60,
        now: @escaping () -> Date = Date.init
    ) {
        self.reader = reader
        self.store = store
        self.estimator = estimator
        self.preferences = preferences
        self.notifier = notifier
        self.connectionObserver = connectionObserver
        self.interval = interval
        self.now = now
    }

    public var threshold: Int { preferences.threshold }

    /// Lịch sử của thiết bị, đọc trên main thread như trạng thái monitor.
    public func history(for deviceId: String) -> [BatterySample] {
        store.samples(for: deviceId)
    }

    /// Bắt đầu poll định kỳ + poll ngay lập tức + lắng nghe kết nối.
    public func start() {
        pollNow()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.pollNow()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        connectionObserver?.onConnect = { [weak self] in
            self?.handleConnect()
        }
        connectionObserver?.start()
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        connectionObserver?.stop()
    }

    /// Khi có thiết bị kết nối: poll ngay rồi poll lại vài lần để chộp giá
    /// trị pin xuất hiện trễ (vd K380 chỉ báo pin ngay sau khi kết nối).
    private func handleConnect() {
        pollNow()
        for delay in Self.connectPollDelays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.pollNow()
            }
        }
    }

    /// Đọc ngay (không chờ timer). Đọc chạy nền, kết quả trả về main thread.
    public func pollNow() {
        workQueue.async { [weak self] in
            guard let self else { return }
            let devices = try? self.reader.fetch()
            DispatchQueue.main.async {
                if let devices { self.handle(devices) }
            }
        }
    }

    // MARK: - Xử lý (main thread)

    private func handle(_ devices: [BluetoothDevice]) {
        let timestamp = now()
        let threshold = preferences.threshold

        // Ghi mẫu cho thiết bị có pin.
        let newSamples = devices.compactMap { device -> BatterySample? in
            guard let pct = device.percent else { return nil }
            return BatterySample(deviceId: device.address, timestamp: timestamp, percent: pct)
        }
        if !newSamples.isEmpty {
            store.append(contentsOf: newSamples, now: timestamp)
        }

        // Tính trạng thái từng thiết bị (dùng giá trị cuối cùng nếu hiện
        // tại không báo pin — vd K380 giữa các lần kết nối).
        var result: [DeviceStatus] = []
        for device in devices {
            let history = store.samples(for: device.address)
            if let status = Self.makeStatus(
                device: device,
                history: history,
                threshold: threshold,
                estimator: estimator,
                now: timestamp
            ) {
                result.append(status)
            }
        }

        // Edge-trigger: chỉ cảnh báo thiết bị vừa chuyển xuống dưới ngưỡng,
        // và chỉ với giá trị đọc mới (không cảnh báo dựa trên giá trị cũ).
        let currentLow = Set(
            result.filter { $0.isLow && !$0.isStale }.map { $0.device.address }
        )
        let newlyLow = currentLow.subtracting(lowDeviceIds)
        for status in result where newlyLow.contains(status.device.address) {
            if let pct = status.device.percent {
                notifier.notifyLowBattery(
                    deviceName: status.device.name,
                    percent: pct,
                    threshold: threshold
                )
            }
        }
        lowDeviceIds = currentLow

        statuses = result
        onUpdate?(result)
    }

    /// Tạo `DeviceStatus` cho một thiết bị (hàm thuần, test được).
    ///
    /// Nếu thiết bị hiện không báo pin nhưng có lịch sử, dùng giá trị cuối
    /// cùng và đánh dấu `isStale`. Trả về nil nếu không có dữ liệu pin nào.
    /// Giá trị pin gần nhất còn được coi là "tươi" trong bao lâu. Thiết bị
    /// HFP (tai nghe) thỉnh thoảng bỏ trống pin một nhịp dù vẫn kết nối;
    /// trong cửa sổ này vẫn hiển thị sáng + ETA thay vì đánh dấu cũ.
    static let freshWindow: TimeInterval = 5 * 60

    static func makeStatus(
        device: BluetoothDevice,
        history: [BatterySample],
        threshold: Int,
        estimator: UsageEstimator,
        now: Date = Date()
    ) -> DeviceStatus? {
        let lastSample = history.max { $0.timestamp < $1.timestamp }
        guard let pct = device.percent ?? lastSample?.percent else { return nil }

        // Chỉ coi là "cũ" khi hiện không báo pin VÀ giá trị gần nhất đã lâu.
        let isStale: Bool
        if device.percent != nil {
            isStale = false
        } else if let last = lastSample, now.timeIntervalSince(last.timestamp) <= freshWindow {
            isStale = false   // vừa báo gần đây => vẫn tươi
        } else {
            isStale = true
        }
        let displayDevice = device.withPercent(pct)

        if isStale {
            // Giá trị cũ: hiển thị % nhưng không suy ra ETA sống.
            return DeviceStatus(
                device: displayDevice,
                estimate: .insufficientData,
                isLow: pct <= threshold,
                isStale: true,
                lastUpdated: lastSample?.timestamp
            )
        }

        let estimate = estimator.estimate(
            samples: history,
            currentPercent: pct,
            threshold: threshold
        )
        return DeviceStatus(
            device: displayDevice,
            estimate: estimate,
            isLow: pct <= threshold && estimate != .charging,
            isStale: false,
            lastUpdated: nil
        )
    }
}
