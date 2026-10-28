import AppKit

/// Merges the three battery sources into one list and keeps it fresh.
final class BatteryMonitor {
    private(set) var devices: [DeviceBattery] = []
    var onUpdate: (() -> Void)?
    var needsInputMonitoring: Bool { hidResult.needsInputMonitoring }

    private let refreshInterval: TimeInterval = 300
    private let hid = HIDBatterySource()
    private let ble = BLEBatterySource()
    private var hidResult = HIDBatterySource.Result()
    private var timer: Timer?
    private var pendingRefresh: DispatchWorkItem?

    func start() {
        hid.onDevicesChanged = { [weak self] in self?.scheduleRefresh(after: 2) }
        ble.onChange = { [weak self] in self?.merge() }
        hid.start()

        // Bluetooth devices take a few seconds to reconnect after the Mac wakes.
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.scheduleRefresh(after: 5)
        }
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }

    func refresh() {
        hid.read { [weak self] result in
            guard let self else { return }
            hidResult = result
            ble.refresh()
            merge()
        }
    }

    /// Connecting a device fires one callback per HID interface, so refreshes are coalesced.
    private func scheduleRefresh(after seconds: TimeInterval) {
        pendingRefresh?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refresh() }
        pendingRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func merge() {
        // macOS's own value wins, then HID, then Bluetooth LE.
        var byName: [String: DeviceBattery] = [:]
        for device in SystemBatterySource.read() + hidResult.readings + ble.readings(knownKinds: hidResult.kinds)
        where byName[device.name] == nil {
            byName[device.name] = device
        }
        devices = byName.values.sorted { ($0.kind.sortOrder, $0.name) < ($1.kind.sortOrder, $1.name) }
        onUpdate?()
    }
}
