import AppKit
import Combine

/// The menu bar item: one device's level (the lowest by default), and a menu row per device.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let monitor = BatteryMonitor.shared
    private let settings = AppSettings.shared
    private let updates = UpdateChecker.shared
    private var subscriptions = Set<AnyCancellable>()

    override init() {
        super.init()
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.imagePosition = .imageLeading

        // @Published fires before the value changes, so update on the next run loop pass.
        Publishers.Merge4(
            monitor.$devices.map { _ in () },
            settings.$menuBarShows.map { _ in () },
            settings.$hiddenDevices.map { _ in () },
            settings.$lowBatteryPercent.map { _ in () }
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in self?.updateButton() }
        .store(in: &subscriptions)
    }

    private func updateButton() {
        guard let button = statusItem.button else { return }
        let device = monitor.menuBarDevice
        button.image = NSImage(systemSymbolName: device?.kind.symbolName ?? "keyboard", accessibilityDescription: "Battery level")
        button.toolTip = device.map { "\($0.displayName): \($0.percent)%" } ?? "No devices reporting battery"

        guard let device, settings.menuBarShows != AppSettings.showIconOnly else {
            button.title = ""
            return
        }
        if device.isLow(threshold: settings.lowBatteryPercent) {
            button.attributedTitle = NSAttributedString(string: " \(device.percent)%", attributes: [
                .foregroundColor: NSColor.systemRed,
                .font: NSFont.menuBarFont(ofSize: 0),
            ])
        } else {
            button.title = " \(device.percent)%"
        }
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if let update = updates.availableUpdate {
            let item = action("Update Available: Version \(update.version)…", #selector(openUpdate))
            item.representedObject = update.url
            menu.addItem(item)
            menu.addItem(.separator())
        }

        let devices = monitor.visibleDevices
        if devices.isEmpty {
            let empty = NSMenuItem(title: "No devices reporting battery", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }
        for device in devices {
            let item = NSMenuItem(title: device.displayName, action: nil, keyEquivalent: "")
            item.attributedTitle = row(for: device)
            item.image = NSImage(systemSymbolName: device.kind.symbolName, accessibilityDescription: nil)
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(action("Refresh", #selector(refresh), key: "r"))
        if monitor.needsInputMonitoring {
            menu.addItem(action("Allow Input Monitoring…", #selector(allowInputMonitoring)))
        }
        if monitor.bluetoothStatus == .denied {
            menu.addItem(action("Allow Bluetooth…", #selector(allowBluetooth)))
        }
        menu.addItem(.separator())
        menu.addItem(action("Settings…", #selector(openSettings), key: ","))
        menu.addItem(action("Check for Updates…", #selector(checkForUpdates)))
        menu.addItem(.separator())
        menu.addItem(action("Quit Bluetooth Battery Bar", #selector(NSApplication.terminate(_:)), key: "q", target: NSApp))
    }

    private func row(for device: DeviceBattery) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.tabStops = [NSTextTab(textAlignment: .right, location: 280)]
        let font = NSFont.menuFont(ofSize: 0)

        let row = NSMutableAttributedString(string: "\(device.displayName)\t", attributes: [.font: font, .paragraphStyle: style])
        if device.isCharging == true, let bolt = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Charging") {
            let attachment = NSTextAttachment()
            attachment.image = bolt
            attachment.bounds = CGRect(x: 0, y: -1, width: 8, height: 11)
            row.append(NSAttributedString(attachment: attachment))
            row.append(NSAttributedString(string: " ", attributes: [.font: font]))
        }
        var percentAttributes: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: style]
        if device.isLow(threshold: settings.lowBatteryPercent) {
            percentAttributes[.foregroundColor] = NSColor.systemRed
        }
        row.append(NSAttributedString(string: "\(device.percent)%\n", attributes: percentAttributes))
        row.append(NSAttributedString(string: "\(device.via) · \(updatedText(device.updated))", attributes: [
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

    @objc private func allowInputMonitoring() {
        InputMonitoring.request()
        InputMonitoring.openSettings()
    }

    @objc private func allowBluetooth() {
        BluetoothPermission.openSettings()
    }

    @objc private func openSettings() {
        SettingsWindow.shared.show()
    }

    @objc private func checkForUpdates() {
        updates.check()
        SettingsWindow.shared.show()
    }

    @objc private func openUpdate(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }
}
