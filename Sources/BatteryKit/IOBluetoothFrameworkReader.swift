import Foundation
import IOBluetooth

/// Đọc pin qua framework public `IOBluetooth` — `IOBluetoothDevice` expose
/// `batteryPercentSingle/Combined/Left/Right/Case`. Đây là nguồn LIVE mà
/// Control Center dùng, bắt được cả tai nghe HFP (vd MOONDROP) mà
/// system_profiler/IORegistry bỏ sót.
public struct IOBluetoothFrameworkReader: BatteryDeviceReading {

    public init() {}

    public func fetch() throws -> [BluetoothDevice] {
        // IOBluetooth nên gọi trên main thread.
        if Thread.isMainThread { return Self.read() }
        return DispatchQueue.main.sync { Self.read() }
    }

    private static func read() -> [BluetoothDevice] {
        guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return []
        }

        var result: [BluetoothDevice] = []
        for device in devices where device.isConnected() {
            let name = device.name ?? "Thiết bị Bluetooth"
            let address = device.addressString.map(BluetoothDevice.normalizeAddress) ?? name

            let single = value(device, "batteryPercentSingle")
            let combined = value(device, "batteryPercentCombined")
            let left = value(device, "batteryPercentLeft")
            let right = value(device, "batteryPercentRight")
            let caseLevel = value(device, "batteryPercentCase")

            let representative = single ?? combined ?? [left, right].compactMap { $0 }.min()
            guard representative != nil || left != nil || right != nil || caseLevel != nil else {
                continue
            }

            result.append(
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
        return result
    }

    /// Đọc selector pin qua KVC; coi 0 là "không có" (chưa báo).
    private static func value(_ device: IOBluetoothDevice, _ key: String) -> Int? {
        guard device.responds(to: Selector(key)),
              let number = (device as NSObject).value(forKey: key) as? NSNumber else {
            return nil
        }
        let v = number.intValue
        return v > 0 ? min(100, v) : nil
    }
}
