import AppKit

/// `KeyBattery --list` prints the current readings and exits, for checking a device without the menu.
func listDevices() -> Never {
    let monitor = BatteryMonitor()
    monitor.start()
    // Gives Bluetooth LE devices time to answer.
    RunLoop.main.run(until: Date().addingTimeInterval(5))

    if monitor.devices.isEmpty { print("No keyboards or mice reporting battery.") }
    for device in monitor.devices {
        print("\(device.percent)%\t\(device.name)\t(\(device.source.rawValue))")
    }
    if monitor.needsInputMonitoring { print("Some devices need Input Monitoring permission.") }
    exit(0)
}

if CommandLine.arguments.contains("--list") {
    listDevices()
}

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.setActivationPolicy(.accessory)
NSApplication.shared.run()
