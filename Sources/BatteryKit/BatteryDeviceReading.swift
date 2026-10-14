import Foundation

/// Nguồn đọc thiết bị Bluetooth + pin.
public protocol BatteryDeviceReading {
    func fetch() throws -> [BluetoothDevice]
}

/// Gộp nhiều nguồn, dedup theo địa chỉ; nguồn đứng trước được ưu tiên,
/// nhưng các trường pin còn thiếu sẽ được bù từ nguồn sau.
public struct CompositeBatteryReader: BatteryDeviceReading {

    private let readers: [BatteryDeviceReading]

    public init(_ readers: [BatteryDeviceReading]) {
        self.readers = readers
    }

    public func fetch() throws -> [BluetoothDevice] {
        var order: [String] = []
        var byAddress: [String: BluetoothDevice] = [:]

        for reader in readers {
            // Một nguồn lỗi không làm hỏng toàn bộ.
            let devices = (try? reader.fetch()) ?? []
            for device in devices {
                if let existing = byAddress[device.address] {
                    byAddress[device.address] = Self.merge(existing, device)
                } else {
                    byAddress[device.address] = device
                    order.append(device.address)
                }
            }
        }

        return order.compactMap { byAddress[$0] }
    }

    /// Giữ giá trị của `base`, bù các trường nil bằng `other`.
    static func merge(_ base: BluetoothDevice, _ other: BluetoothDevice) -> BluetoothDevice {
        BluetoothDevice(
            address: base.address,
            name: base.name.isEmpty ? other.name : base.name,
            percent: base.percent ?? other.percent,
            left: base.left ?? other.left,
            right: base.right ?? other.right,
            caseLevel: base.caseLevel ?? other.caseLevel,
            minorType: base.minorType ?? other.minorType
        )
    }
}
