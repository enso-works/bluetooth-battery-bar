import Combine
import Foundation
import UserNotifications

/// Sends one notification when a visible device drops to the low-battery level, and another
/// only after it has been charged above that level again.
final class LowBatteryAlerts {
    static let shared = LowBatteryAlerts()

    /// Margin above the threshold that counts as charged, so a level hovering at it doesn't re-alert.
    private let rechargeMargin = 5
    private let settings = AppSettings.shared
    private let monitor = BatteryMonitor.shared
    private var warnedDevices = Set<String>()
    private var subscriptions = Set<AnyCancellable>()

    private init() {}

    func start() {
        if settings.notifyLowBattery { requestPermission() }
        settings.$notifyLowBattery
            .dropFirst()
            .filter { $0 }
            .sink { [weak self] _ in self?.requestPermission() }
            .store(in: &subscriptions)
        // @Published fires before the value changes, so check on the next run loop pass.
        monitor.$devices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.check() }
            .store(in: &subscriptions)
    }

    private func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func check() {
        let threshold = settings.lowBatteryPercent
        for device in monitor.visibleDevices {
            if device.isLow(threshold: threshold) {
                guard warnedDevices.insert(device.id).inserted, settings.notifyLowBattery else { continue }
                let content = UNMutableNotificationContent()
                content.title = "\(device.displayName) battery low"
                content.body = "\(device.percent)% left."
                content.sound = .default
                UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "low-\(device.id)", content: content, trigger: nil))
            } else if device.percent > threshold + rechargeMargin || device.isCharging == true {
                warnedDevices.remove(device.id)
            }
        }
    }
}
