import Foundation
import UserNotifications

/// Bọc UserNotifications để gửi cảnh báo pin thấp.
public final class NotificationManager {

    private let center = UNUserNotificationCenter.current()
    private var authorized = false

    public init() {}

    /// Xin quyền gửi notification.
    public func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            self?.authorized = granted
        }
    }

    /// Gửi cảnh báo một thiết bị pin thấp.
    public func notifyLowBattery(deviceName: String, percent: Int, threshold: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Pin Bluetooth thấp"
        content.body = "\(deviceName) còn \(percent)% (dưới \(threshold)%). Hãy sạc sớm."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "low-battery-\(deviceName)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request, withCompletionHandler: nil)
    }
}
