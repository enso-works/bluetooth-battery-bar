import AppKit
import ServiceManagement
import UserNotifications

/// Menu bar item showing the lowest battery level, with one menu row per device.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let lowBatteryPercent = 20
    private let monitor = BatteryMonitor()
    private var statusItem: NSStatusItem!
    private var warnedDevices = Set<String>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = menu
        statusItem.button?.imagePosition = .imageLeading

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        monitor.onUpdate = { [weak self] in self?.devicesDidUpdate() }
        monitor.start()
        devicesDidUpdate()
    }

    private func devicesDidUpdate() {
        guard let button = statusItem.button else { return }
        let lowest = monitor.devices.min { $0.percent < $1.percent }
        button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Keyboard battery")

        if let lowest, lowest.percent <= lowBatteryPercent {
            button.attributedTitle = NSAttributedString(string: " \(lowest.percent)%", attributes: [
                .foregroundColor: NSColor.systemRed,
                .font: NSFont.menuBarFont(ofSize: 0),
            ])
        } else {
            button.title = lowest.map { " \($0.percent)%" } ?? ""
        }
        button.toolTip = lowest.map { "\($0.name): \($0.percent)%" } ?? "No keyboards or mice reporting battery"
        warnIfLow()
    }

    private func warnIfLow() {
        for device in monitor.devices {
            if device.percent <= lowBatteryPercent, warnedDevices.insert(device.name).inserted {
                let content = UNMutableNotificationContent()
                content.title = "\(device.name) battery low"
                content.body = "\(device.percent)% left."
                UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "low-\(device.name)", content: content, trigger: nil))
            } else if device.percent > lowBatteryPercent + 5 {
                // Charged again, so warn again next time it runs low.
                warnedDevices.remove(device.name)
            }
        }
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if monitor.devices.isEmpty {
            let empty = NSMenuItem(title: "No keyboards or mice reporting battery", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }
        for device in monitor.devices {
            let item = NSMenuItem(title: device.name, action: nil, keyEquivalent: "")
            item.attributedTitle = row(for: device)
            item.image = NSImage(systemSymbolName: device.kind.symbolName, accessibilityDescription: nil)
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(action("Refresh", #selector(refresh), key: "r"))
        if monitor.needsInputMonitoring {
            menu.addItem(action("Allow Input Monitoring…", #selector(openInputMonitoringSettings)))
        }
        let login = action("Launch at Login", #selector(toggleLaunchAtLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(action("Quit KeyBattery", #selector(NSApplication.terminate(_:)), key: "q", target: NSApp))
    }

    private func row(for device: DeviceBattery) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.tabStops = [NSTextTab(textAlignment: .right, location: 260)]
        let percent = "\(device.percent)%"

        let row = NSMutableAttributedString(string: "\(device.name)\t\(percent)\n", attributes: [
            .font: NSFont.menuFont(ofSize: 0),
            .paragraphStyle: style,
        ])
        if device.percent <= lowBatteryPercent {
            row.addAttribute(.foregroundColor, value: NSColor.systemRed, range: (row.string as NSString).range(of: percent, options: .backwards))
        }
        row.append(NSAttributedString(string: "\(device.source.rawValue) · \(updatedText(device.updated))", attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: style,
        ]))
        return row
    }

    private func updatedText(_ date: Date) -> String {
        guard Date().timeIntervalSince(date) >= 60 else { return "updated just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "updated " + formatter.localizedString(for: date, relativeTo: Date())
    }

    private func action(_ title: String, _ selector: Selector, key: String = "", target: AnyObject? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = target ?? self
        return item
    }

    @objc private func refresh() {
        monitor.refresh()
    }

    @objc private func openInputMonitoringSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSApp.activate(ignoringOtherApps: true)
            NSAlert(error: error).runModal()
        }
    }
}
