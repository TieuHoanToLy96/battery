import AppKit
import BatteryKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var controller: MenuBarController?
    private var monitor: BatteryMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installEditMenu()

        let preferences = Preferences()
        let notifier = NotificationManager()
        notifier.requestAuthorization()

        // Dùng subprocess reader cho IOBluetooth (tránh cache trong app sống lâu).
        let reader = CompositeBatteryReader([
            IOBluetoothSubprocessReader(),
            IORegistryBatteryReader(),
            BluetoothBatteryReader(),
        ])
        let monitor = BatteryMonitor(reader: reader, preferences: preferences, notifier: notifier)
        let controller = MenuBarController(monitor: monitor, preferences: preferences)
        controller.install()
        monitor.start()

        self.monitor = monitor
        self.controller = controller
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
    }

    /// App accessory không có main menu nên Cmd+A/C/V/X không route tới ô
    /// nhập. Cài một Edit menu tối thiểu để bật các phím tắt chỉnh sửa text.
    private func installEditMenu() {
        let mainMenu = NSMenu()
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)

        let editMenu = NSMenu(title: "Edit")
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }
}
