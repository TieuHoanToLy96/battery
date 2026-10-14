import AppKit
import BatteryKit

// Chế độ nội bộ: đọc IOBluetooth (tiến trình tươi, tránh cache) rồi in JSON.
if CommandLine.arguments.contains("--bt-json") {
    let devices = (try? IOBluetoothFrameworkReader().fetch()) ?? []
    if let data = try? JSONEncoder().encode(devices),
       let json = String(data: data, encoding: .utf8) {
        print(json)
    } else {
        print("[]")
    }
    exit(0)
}

// Chế độ debug: `battery --search "từ khoá"` in kết quả YouTube rồi thoát.
if let i = CommandLine.arguments.firstIndex(of: "--search"), i + 1 < CommandLine.arguments.count {
    let query = CommandLine.arguments[i + 1]
    YouTubeSearch.search(query) { results in
        for r in results.prefix(6) { print("\(r.videoId) | \(r.title) — \(r.author)") }
        if results.isEmpty { print("KHÔNG có kết quả") }
        CFRunLoopStop(CFRunLoopGetMain())
    }
    CFRunLoopRun()
    exit(0)
}

// Chế độ debug: `battery --once` in danh sách thiết bị + pin rồi thoát.
if CommandLine.arguments.contains("--once") {
    let reader = CompositeBatteryReader([
        IOBluetoothFrameworkReader(),
        IORegistryBatteryReader(),
        BluetoothBatteryReader(),
    ])
    let devices = (try? reader.fetch()) ?? []
    let formatter = StatusFormatter()
    if devices.isEmpty {
        print("Không có thiết bị Bluetooth báo pin.")
    } else {
        for device in devices {
            var line = formatter.deviceLabel(device)
            if let components = formatter.componentsText(device) {
                line += "  (\(components))"
            }
            print(line)
        }
    }
    exit(0)
}

// Menu bar accessory app: không hiện icon trên Dock.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
