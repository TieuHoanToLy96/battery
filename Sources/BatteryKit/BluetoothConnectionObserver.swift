import Foundation
import IOBluetooth

/// Lắng nghe sự kiện thiết bị Bluetooth kết nối để kích hoạt đọc pin ngay.
///
/// Nhiều thiết bị (vd Logitech K380) chỉ gửi % pin trong khoảnh khắc ngay
/// sau khi (re)connect; poll định kỳ 60s dễ trượt cửa sổ đó. Đọc ngay khi
/// nhận sự kiện kết nối giúp chộp được giá trị.
public final class BluetoothConnectionObserver: NSObject {

    /// Gọi (trên main thread) mỗi khi có thiết bị Bluetooth kết nối.
    public var onConnect: (() -> Void)?

    private var notification: IOBluetoothUserNotification?

    public override init() {
        super.init()
    }

    public func start() {
        // macOS abort (TCC) nếu dùng IOBluetooth mà Info.plist thiếu
        // NSBluetoothAlwaysUsageDescription — vd khi chạy `swift run` không
        // qua bundle. Bỏ qua đăng ký trong trường hợp đó để không crash.
        guard Bundle.main.object(forInfoDictionaryKey: "NSBluetoothAlwaysUsageDescription") != nil else {
            NSLog("BluetoothConnectionObserver: thiếu NSBluetoothAlwaysUsageDescription, bỏ qua connect notifications.")
            return
        }
        // Đăng ký nhận thông báo cho MỌI thiết bị kết nối.
        notification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceConnected(_:device:))
        )
    }

    public func stop() {
        notification?.unregister()
        notification = nil
    }

    @objc private func deviceConnected(
        _ notification: IOBluetoothUserNotification,
        device: IOBluetoothDevice
    ) {
        onConnect?()
    }
}
