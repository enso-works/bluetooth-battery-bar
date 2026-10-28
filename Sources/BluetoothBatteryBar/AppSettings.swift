import Foundation

/// User preferences, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    static let lowBatteryRange: ClosedRange<Double> = 5...50
    /// `menuBarShows` values besides a device ID.
    static let showLowest = "lowest"
    static let showIconOnly = "icon"

    private enum Key {
        static let menuBarShows = "menuBarShows"
        static let hiddenDevices = "hiddenDevices"
        static let notifyLowBattery = "notifyLowBattery"
        static let lowBatteryPercent = "lowBatteryPercent"
        static let checkForUpdates = "checkForUpdates"
        static let lastUpdateCheck = "lastUpdateCheck"
    }

    private let defaults = UserDefaults.standard

    /// The lowest battery, one device's ID, or only the icon.
    @Published var menuBarShows: String {
        didSet { defaults.set(menuBarShows, forKey: Key.menuBarShows) }
    }

    /// Devices left out of the menu, the menu bar and alerts.
    @Published var hiddenDevices: Set<String> {
        didSet { defaults.set(hiddenDevices.sorted(), forKey: Key.hiddenDevices) }
    }

    @Published var notifyLowBattery: Bool {
        didSet { defaults.set(notifyLowBattery, forKey: Key.notifyLowBattery) }
    }

    /// At or below this level a device counts as low: red in the menu bar and one notification.
    @Published var lowBatteryPercent: Int {
        didSet { defaults.set(lowBatteryPercent, forKey: Key.lowBatteryPercent) }
    }

    /// Opt-in: asks GitHub for the latest release at most once a day.
    @Published var checkForUpdates: Bool {
        didSet { defaults.set(checkForUpdates, forKey: Key.checkForUpdates) }
    }

    var lastUpdateCheck: Date? {
        get { defaults.object(forKey: Key.lastUpdateCheck) as? Date }
        set { defaults.set(newValue, forKey: Key.lastUpdateCheck) }
    }

    private init() {
        defaults.register(defaults: [
            Key.menuBarShows: Self.showLowest,
            Key.notifyLowBattery: true,
            Key.lowBatteryPercent: 20,
            Key.checkForUpdates: false,
        ])
        menuBarShows = defaults.string(forKey: Key.menuBarShows) ?? Self.showLowest
        hiddenDevices = Set(defaults.stringArray(forKey: Key.hiddenDevices) ?? [])
        notifyLowBattery = defaults.bool(forKey: Key.notifyLowBattery)
        lowBatteryPercent = defaults.integer(forKey: Key.lowBatteryPercent)
        checkForUpdates = defaults.bool(forKey: Key.checkForUpdates)
    }

    func setHidden(_ hidden: Bool, deviceID: String) {
        if hidden {
            hiddenDevices.insert(deviceID)
        } else {
            hiddenDevices.remove(deviceID)
        }
    }
}
