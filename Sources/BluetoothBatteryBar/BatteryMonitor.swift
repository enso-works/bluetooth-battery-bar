import AppKit

/// Merges the battery sources into one list and keeps it fresh.
final class BatteryMonitor: ObservableObject {
    static let shared = BatteryMonitor()

    /// Every device reporting a battery level, hidden ones included.
    @Published private(set) var devices: [DeviceBattery] = []
    @Published private(set) var needsInputMonitoring = false
    @Published private(set) var bluetoothStatus: BLEBatterySource.Status = .unknown

    private let refreshInterval: TimeInterval = 300
    private let settings = AppSettings.shared
    private let hid = HIDBatterySource()
    private let ble = BLEBatterySource()
    private let controllers = ControllerBatterySource()
    private var hidResult = HIDBatterySource.Result()
    private var timer: Timer?
    private var pendingRefresh: DispatchWorkItem?

    private init() {}

    var visibleDevices: [DeviceBattery] {
        devices.filter { !settings.hiddenDevices.contains($0.id) }
    }

    /// The device whose level the menu bar shows: the one chosen in Settings, or the lowest.
    var menuBarDevice: DeviceBattery? {
        let visible = visibleDevices
        return visible.first { $0.id == settings.menuBarShows } ?? visible.min { $0.percent < $1.percent }
    }

    func start() {
        hid.onDevicesChanged = { [weak self] in self?.scheduleRefresh(after: 2) }
        ble.onChange = { [weak self] in self?.merge() }
        controllers.onChange = { [weak self] in self?.scheduleRefresh(after: 1) }
        hid.start()
        ble.start()
        controllers.start()

        // Bluetooth devices take a few seconds to reconnect after the Mac wakes.
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.scheduleRefresh(after: 5)
        }
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        // Starting the HID manager reports every connected device, which schedules a refresh as
        // well; coalescing makes it one read per device at launch instead of two.
        scheduleRefresh(after: 1)
    }

    func refresh() {
        hid.read { [weak self] result in
            guard let self else { return }
            hidResult = result
            ble.refresh()
            merge()
        }
    }

    /// Cheap enough to call every few seconds while Settings is open.
    func refreshPermissions() {
        let needed = !InputMonitoring.isGranted
        if needsInputMonitoring != needed { needsInputMonitoring = needed }
        if bluetoothStatus != ble.status { bluetoothStatus = ble.status }
    }

    /// Connecting a device fires one callback per HID interface, so refreshes are coalesced.
    private func scheduleRefresh(after seconds: TimeInterval) {
        pendingRefresh?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refresh() }
        pendingRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func merge() {
        // Earlier sources win when two report the same device: macOS's own value, then the
        // controller framework (it knows about charging), then HID, then Bluetooth LE.
        let all = SystemBatterySource.read() + controllers.read() + hidResult.readings + ble.readings(knownKinds: hidResult.kinds)
        var merged: [DeviceBattery] = []
        for device in all where !merged.contains(where: { $0.name == device.name && ($0.part == nil || $0.part == device.part) }) {
            merged.append(device)
        }
        merged.sort { ($0.kind.sortOrder, $0.displayName) < ($1.kind.sortOrder, $1.displayName) }

        if merged != devices { devices = merged }
        if needsInputMonitoring != hidResult.needsInputMonitoring { needsInputMonitoring = hidResult.needsInputMonitoring }
        if bluetoothStatus != ble.status { bluetoothStatus = ble.status }
    }

    #if SCREENSHOTS
    func showDemo(_ devices: [DeviceBattery], needsInputMonitoring: Bool) {
        self.devices = devices
        self.needsInputMonitoring = needsInputMonitoring
        bluetoothStatus = .ready
    }
    #endif
}
