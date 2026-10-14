import Foundation
import BatteryKit

/// Đọc pin IOBluetooth bằng cách gọi CHÍNH app với cờ `--bt-json` trong một
/// tiến trình con tươi. Cần vì `IOBluetoothDevice` cache giá trị pin theo
/// vòng đời tiến trình — tiến trình sống lâu (app) không refresh, còn tiến
/// trình mới luôn đọc đúng giá trị live.
struct IOBluetoothSubprocessReader: BatteryDeviceReading {

    func fetch() throws -> [BluetoothDevice] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        process.arguments = ["--bt-json"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        try process.run()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return (try? JSONDecoder().decode([BluetoothDevice].self, from: data)) ?? []
    }
}
