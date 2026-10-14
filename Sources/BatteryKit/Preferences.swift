import Foundation

/// Cấu hình người dùng, lưu qua UserDefaults.
public final class Preferences {

    private enum Keys {
        static let threshold = "warningThreshold"
        static let skipSeconds = "skipSeconds"
        static let eqGains = "eqGains"
        static let lastSearch = "lastSearchQuery"
        static let loop = "loopEnabled"
    }

    public static let defaultThreshold = 20
    public static let availableThresholds = [10, 15, 20, 25, 30, 50, 60]

    public static let defaultSkipSeconds = 10
    public static let availableSkipSteps = [10, 20, 30, 60, 300]

    public static let defaultEQGains = [0.0, 0, 0, 0, 0, 0]

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Keys.threshold) == nil {
            defaults.set(Self.defaultThreshold, forKey: Keys.threshold)
        }
    }

    /// Ngưỡng cảnh báo (%).
    public var threshold: Int {
        get { defaults.integer(forKey: Keys.threshold) }
        set { defaults.set(newValue, forKey: Keys.threshold) }
    }

    /// Bước tua nhanh/lùi (giây).
    public var skipSeconds: Int {
        get {
            let v = defaults.integer(forKey: Keys.skipSeconds)
            return v == 0 ? Self.defaultSkipSeconds : v
        }
        set { defaults.set(newValue, forKey: Keys.skipSeconds) }
    }

    /// Gain EQ (dB) cho 6 dải (cho YouTube/Chrome).
    public var eqGains: [Double] {
        get {
            let v = defaults.array(forKey: Keys.eqGains) as? [Double]
            return (v?.count == Self.defaultEQGains.count) ? v! : Self.defaultEQGains
        }
        set { defaults.set(newValue, forKey: Keys.eqGains) }
    }

    /// EQ có đang ở mức phẳng (không chỉnh) không.
    public var eqIsFlat: Bool { eqGains.allSatisfy { $0 == 0 } }

    /// Từ khoá tìm kiếm YouTube gần nhất.
    public var lastSearchQuery: String {
        get { defaults.string(forKey: Keys.lastSearch) ?? "" }
        set { defaults.set(newValue, forKey: Keys.lastSearch) }
    }

    /// Lặp lại video YouTube.
    public var loopEnabled: Bool {
        get { defaults.bool(forKey: Keys.loop) }
        set { defaults.set(newValue, forKey: Keys.loop) }
    }
}
