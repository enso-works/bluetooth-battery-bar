import Foundation
import GameController

/// Game controllers macOS knows, such as Xbox, DualSense, DualShock 4 and Switch Pro controllers,
/// through Apple's GameController framework. This is the only source that reports charging.
final class ControllerBatterySource {
    var onChange: (() -> Void)?

    private var observers: [NSObjectProtocol] = []

    func start() {
        for name in [Notification.Name.GCControllerDidConnect, .GCControllerDidDisconnect] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.onChange?()
            })
        }
    }

    func read() -> [DeviceBattery] {
        GCController.controllers().compactMap { controller in
            guard let battery = controller.battery else { return nil }
            let name = controller.vendorName ?? "Game controller"
            let isCharging: Bool? = switch battery.batteryState {
            case .charging, .full: true
            case .discharging: false
            default: nil
            }
            return DeviceBattery(id: "controller:\(name)", name: name, part: nil, kind: .gamepad,
                                 percent: Int((battery.batteryLevel * 100).rounded()), isCharging: isCharging,
                                 via: "Game controller", updated: Date())
        }
    }
}
