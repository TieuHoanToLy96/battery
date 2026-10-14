import AppKit
import BatteryKit

/// Chọn SF Symbol cho icon ở giữa vòng pin theo loại thiết bị.
enum DeviceIconMapper {

    /// Danh sách symbol ưu tiên (thử lần lượt tới khi tạo được ảnh).
    static func symbolCandidates(for device: BluetoothDevice) -> [String] {
        let hay = ((device.minorType ?? "") + " " + device.name).lowercased()

        func has(_ keywords: [String]) -> Bool { keywords.contains { hay.contains($0) } }

        if has(["headset", "headphone", "airpod", "buds", "earphone", "pod", "moondrop", "audio"]) {
            return ["headphones"]
        }
        if has(["keyboard"]) { return ["keyboard"] }
        if has(["trackpad"]) {
            return ["rectangle.and.hand.point.up.left.fill", "hand.point.up.left.fill", "rectangle.fill"]
        }
        if has(["mouse"]) { return ["computermouse.fill", "computermouse"] }
        if has(["pencil", "stylus"]) { return ["pencil"] }
        if has(["game", "controller", "gamepad"]) { return ["gamecontroller.fill"] }
        return ["dot.radiowaves.left.and.right"]
    }

    /// Ảnh icon đã cấu hình màu, hoặc nil nếu không tạo được symbol nào.
    static func image(for device: BluetoothDevice, pointSize: CGFloat, color: NSColor) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
            .applying(.init(paletteColors: [color]))
        for name in symbolCandidates(for: device) {
            if let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(config) {
                return image
            }
        }
        return nil
    }
}
