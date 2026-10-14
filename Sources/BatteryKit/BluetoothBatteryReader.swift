import Foundation

/// Đọc danh sách thiết bị Bluetooth kết nối + pin từ `system_profiler`.
///
/// Việc chạy tiến trình (`fetch`) tách khỏi việc phân tích JSON (`parse`)
/// để `parse` có thể test bằng dữ liệu cố định.
public struct BluetoothBatteryReader: BatteryDeviceReading {

    public enum ReaderError: Error {
        case processFailed(String)
    }

    public init() {}

    /// Chạy `system_profiler SPBluetoothDataType -json` và trả về thiết bị kết nối.
    public func fetch() throws -> [BluetoothDevice] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json"]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw ReaderError.processFailed(error.localizedDescription)
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let msg = String(
                data: stderr.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? "exit \(process.terminationStatus)"
            throw ReaderError.processFailed(msg)
        }

        return Self.parse(data)
    }

    /// Phân tích output JSON của `system_profiler` thành danh sách thiết bị kết nối.
    ///
    /// Cấu trúc: `{ "SPBluetoothDataType": [ { "device_connected": [ { "Tên": {props} } ] } ] }`.
    /// Mỗi `props` có thể chứa `device_address`, `device_batteryLevelMain`,
    /// `device_batteryLevelLeft/Right/Case` (chuỗi dạng "80%").
    public static func parse(_ data: Data) -> [BluetoothDevice] {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let sections = root["SPBluetoothDataType"] as? [[String: Any]]
        else {
            return []
        }

        var devices: [BluetoothDevice] = []
        for section in sections {
            guard let connected = section["device_connected"] as? [[String: Any]] else {
                continue
            }
            for entry in connected {
                // Mỗi entry là dict một khóa: tên -> thuộc tính.
                guard let (name, raw) = entry.first,
                      let props = raw as? [String: Any] else { continue }

                let address = (props["device_address"] as? String)
                    .map(BluetoothDevice.normalizeAddress) ?? name
                let main = percentValue(props["device_batteryLevelMain"])
                let left = percentValue(props["device_batteryLevelLeft"])
                let right = percentValue(props["device_batteryLevelRight"])
                let caseLevel = percentValue(props["device_batteryLevelCase"])

                let representative = main ?? [left, right].compactMap { $0 }.min()

                devices.append(
                    BluetoothDevice(
                        address: address,
                        name: name,
                        percent: representative,
                        left: left,
                        right: right,
                        caseLevel: caseLevel,
                        minorType: props["device_minorType"] as? String
                    )
                )
            }
        }
        return devices
    }

    /// Chuyển giá trị pin ("80%", "80", 80) thành Int. nil nếu không parse được.
    static func percentValue(_ value: Any?) -> Int? {
        if let i = value as? Int { return clamp(i) }
        if let s = value as? String {
            let digits = s.trimmingCharacters(in: CharacterSet(charactersIn: "% "))
            if let i = Int(digits) { return clamp(i) }
        }
        return nil
    }

    private static func clamp(_ i: Int) -> Int { max(0, min(100, i)) }
}
