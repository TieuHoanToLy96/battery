import Foundation

/// Lưu trữ lịch sử mẫu pin ra file JSON, tự prune mẫu cũ hơn `retention`.
public final class UsageHistoryStore {

    public static let defaultRetention: TimeInterval = 30 * 24 * 60 * 60

    private let fileURL: URL
    private let retention: TimeInterval
    private var samples: [BatterySample]

    /// - Parameters:
    ///   - fileURL: vị trí file. nil = dùng Application Support mặc định.
    ///   - retention: giữ lại mẫu trong bao lâu (mặc định 30 ngày).
    public init(fileURL: URL? = nil, retention: TimeInterval = UsageHistoryStore.defaultRetention) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.retention = retention
        self.samples = Self.load(from: self.fileURL)
    }

    /// Thêm một mẫu, prune mẫu cũ, ghi xuống đĩa.
    public func append(_ sample: BatterySample) {
        samples.append(sample)
        prune(now: sample.timestamp)
        save()
    }

    /// Thêm nhiều mẫu cùng lúc (một lần ghi đĩa).
    public func append(contentsOf newSamples: [BatterySample], now: Date) {
        samples.append(contentsOf: newSamples)
        prune(now: now)
        save()
    }

    /// Lấy toàn bộ mẫu của một thiết bị.
    public func samples(for deviceId: String) -> [BatterySample] {
        samples.filter { $0.deviceId == deviceId }
    }

    /// Mẫu mới nhất của một thiết bị (giá trị pin "gần nhất đã biết").
    public func lastSample(for deviceId: String) -> BatterySample? {
        samples
            .filter { $0.deviceId == deviceId }
            .max { $0.timestamp < $1.timestamp }
    }

    public var allSamples: [BatterySample] { samples }

    // MARK: - Private

    private func prune(now: Date) {
        let cutoff = now.addingTimeInterval(-retention)
        samples.removeAll { $0.timestamp < cutoff }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(samples)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Lỗi ghi không nên làm sập app — bỏ qua, sẽ thử lại lần sau.
            NSLog("UsageHistoryStore save failed: \(error)")
        }
    }

    private static func load(from url: URL) -> [BatterySample] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // File hỏng -> coi như rỗng.
        return (try? decoder.decode([BatterySample].self, from: data)) ?? []
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("BatteryMenuBar", isDirectory: true)
            .appendingPathComponent("history.json")
    }
}
