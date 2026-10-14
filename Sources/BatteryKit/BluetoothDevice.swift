import Foundation

/// Một thiết bị Bluetooth đang kết nối cùng thông tin pin.
public struct BluetoothDevice: Equatable, Identifiable, Codable {
    /// Địa chỉ Bluetooth, dùng làm định danh ổn định.
    public let address: String
    public let name: String

    /// % pin đại diện dùng cho ước lượng/cảnh báo.
    /// - Với thiết bị thường: `batteryLevelMain`.
    /// - Với AirPods (không có Main): min(left, right).
    public let percent: Int?

    /// Các mức pin thành phần (chủ yếu cho AirPods). nil nếu không có.
    public let left: Int?
    public let right: Int?
    public let caseLevel: Int?

    /// Loại thiết bị (vd "Keyboard", "Headset", "Trackpad") để chọn icon.
    public let minorType: String?

    public var id: String { address }

    public init(
        address: String,
        name: String,
        percent: Int?,
        left: Int? = nil,
        right: Int? = nil,
        caseLevel: Int? = nil,
        minorType: String? = nil
    ) {
        self.address = address
        self.name = name
        self.percent = percent
        self.left = left
        self.right = right
        self.caseLevel = caseLevel
        self.minorType = minorType
    }

    /// true nếu thiết bị có ít nhất một chỉ số pin.
    public var hasBattery: Bool {
        percent != nil || left != nil || right != nil || caseLevel != nil
    }

    /// Chuẩn hoá địa chỉ BT về dạng so khớp được giữa các nguồn.
    /// "A0:78:17:E2:B9:B4" và "a0-78-17-e2-b9-b4" => "a07817e2b9b4".
    public static func normalizeAddress(_ raw: String) -> String {
        raw.lowercased().filter { $0.isHexDigit }
    }

    /// Bản sao với % pin đại diện khác (giữ nguyên các trường còn lại).
    public func withPercent(_ newPercent: Int?) -> BluetoothDevice {
        BluetoothDevice(
            address: address,
            name: name,
            percent: newPercent,
            left: left,
            right: right,
            caseLevel: caseLevel,
            minorType: minorType
        )
    }
}

/// Một mẫu pin ghi lại tại một thời điểm, dùng để tính lịch sử sử dụng.
public struct BatterySample: Codable, Equatable {
    public let deviceId: String
    public let timestamp: Date
    public let percent: Int

    public init(deviceId: String, timestamp: Date, percent: Int) {
        self.deviceId = deviceId
        self.timestamp = timestamp
        self.percent = percent
    }
}
