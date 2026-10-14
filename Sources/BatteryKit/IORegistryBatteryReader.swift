import Foundation

/// Đọc pin thiết bị Bluetooth từ IORegistry qua `ioreg -a` (output plist).
///
/// IORegistry expose pin cho nhiều thiết bị mà `system_profiler` bỏ sót
/// (bàn phím, chuột, trackpad, nhiều tai nghe), kèm `DeviceAddress`,
/// `Product` và các khóa AirPods `BatteryPercentLeft/Right/Case`.
public struct IORegistryBatteryReader: BatteryDeviceReading {

    public enum ReaderError: Error {
        case processFailed(String)
    }

    /// Các khóa pin dùng để truy vấn ioreg (gộp kết quả).
    private static let queryKeys = ["BatteryPercent", "BatteryPercentCombined"]

    public init() {}

    public func fetch() throws -> [BluetoothDevice] {
        var order: [String] = []
        var byAddress: [String: BluetoothDevice] = [:]

        for key in Self.queryKeys {
            let data = try Self.runIOReg(key: key)
            for device in Self.parse(data) {
                if let existing = byAddress[device.address] {
                    byAddress[device.address] = CompositeBatteryReader.merge(existing, device)
                } else {
                    byAddress[device.address] = device
                    order.append(device.address)
                }
            }
        }
        return order.compactMap { byAddress[$0] }
    }

    /// Phân tích plist từ `ioreg -a -r -l -k <key>` thành danh sách thiết bị.
    public static func parse(_ data: Data) -> [BluetoothDevice] {
        guard !data.isEmpty,
              let obj = try? PropertyListSerialization.propertyList(from: data, format: nil)
        else { return [] }

        let nodes: [[String: Any]]
        if let array = obj as? [[String: Any]] {
            nodes = array
        } else if let dict = obj as? [String: Any] {
            nodes = [dict]
        } else {
            return []
        }

        var devices: [BluetoothDevice] = []
        for node in nodes {
            let main = intValue(node["BatteryPercent"])
            let combined = intValue(node["BatteryPercentCombined"])
            let left = intValue(node["BatteryPercentLeft"])
            let right = intValue(node["BatteryPercentRight"])
            let caseLevel = intValue(node["BatteryPercentCase"])

            let representative = main ?? combined ?? [left, right].compactMap { $0 }.min()
            // Bỏ node không có chỉ số pin nào.
            guard representative != nil || left != nil || right != nil || caseLevel != nil else {
                continue
            }

            let name = (node["Product"] as? String) ?? "Thiết bị Bluetooth"
            let address = (node["DeviceAddress"] as? String)
                .map(BluetoothDevice.normalizeAddress) ?? name

            devices.append(
                BluetoothDevice(
                    address: address,
                    name: name,
                    percent: representative,
                    left: left,
                    right: right,
                    caseLevel: caseLevel
                )
            )
        }
        return devices
    }

    // MARK: - Private

    private static func runIOReg(key: String) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        process.arguments = ["-a", "-r", "-l", "-k", key]

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            throw ReaderError.processFailed(error.localizedDescription)
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return data
    }

    static func intValue(_ value: Any?) -> Int? {
        if let i = value as? Int { return clamp(i) }
        if let n = value as? NSNumber { return clamp(n.intValue) }
        if let s = value as? String, let i = Int(s) { return clamp(i) }
        return nil
    }

    private static func clamp(_ i: Int) -> Int { max(0, min(100, i)) }
}
