import AppKit

@main
enum BluetoothBatteryBarApp {
    static func main() {
        if CommandLine.arguments.contains("--list") {
            ListCommand.run()
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hasLaunchedKey = "hasLaunchedBefore"
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        BatteryMonitor.shared.start()
        LowBatteryAlerts.shared.start()
        UpdateChecker.shared.startAutomaticChecks()
        statusItem = StatusItemController()

        let isFirstLaunch = !UserDefaults.standard.bool(forKey: hasLaunchedKey)
        UserDefaults.standard.set(true, forKey: hasLaunchedKey)
        if isFirstLaunch {
            SettingsWindow.shared.show()
        }
    }

    /// Opening the app again (e.g. from Finder or Spotlight) shows its settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindow.shared.show()
        return true
    }
}

/// `--list` prints the current readings and exits, for checking a device from Terminal.
enum ListCommand {
    static func run() -> Never {
        let monitor = BatteryMonitor.shared
        monitor.start()
        // Gives Bluetooth LE devices time to answer.
        RunLoop.main.run(until: Date().addingTimeInterval(5))

        if monitor.devices.isEmpty { print("No devices reporting battery.") }
        for device in monitor.devices {
            let charging = device.isCharging == true ? ", charging" : ""
            print("\(device.percent)%\t\(device.displayName)\t(\(device.via)\(charging))")
        }
        if monitor.needsInputMonitoring {
            print("Input Monitoring is off, so Bluetooth keyboards can't be read.")
        }
        exit(0)
    }
}
