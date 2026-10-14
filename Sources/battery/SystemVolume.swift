import Foundation

/// Đọc/đặt âm lượng đầu ra hệ thống qua AppleScript (StandardAdditions).
///
/// Dùng AppleScript thay CoreAudio vì nhiều tai nghe Bluetooth không expose
/// `kAudioDevicePropertyVolumeScalar`, trong khi `set volume output volume`
/// điều khiển được (gửi absolute volume). Không cần quyền Automation.
enum SystemVolume {

    /// Âm lượng hiện tại 0..1, nil nếu không đọc được.
    static func current() -> Float? {
        guard let result = run("output volume of (get volume settings)") else { return nil }
        let pct = result.int32Value
        guard pct >= 0, pct <= 100 else { return nil }
        return Float(pct) / 100.0
    }

    /// Đặt âm lượng 0..1.
    static func set(_ value: Float) {
        let pct = Int((max(0, min(1, value)) * 100).rounded())
        _ = run("set volume output volume \(pct)")
    }

    @discardableResult
    private static func run(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        let result = script?.executeAndReturnError(&error)
        return error == nil ? result : nil
    }
}
