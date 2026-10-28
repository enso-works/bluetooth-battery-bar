import Foundation
import IOKit.hid
import os

private let log = Logger(subsystem: "works.enso.BluetoothBatteryBar", category: "hid")

private let batteryStrengthUsagePage = 0x06
private let batteryStrengthUsage = 0x20
private let getValueWithUpdate: IOOptionBits = 0x0002_0000

/// Any HID device that declares a "Battery Strength" field (usage page 0x06, usage 0x20), over any
/// connection: classic Bluetooth keyboards like the Keychron K-series, USB receivers, and so on.
/// These devices only send the value when asked, so every read requests a fresh report.
final class HIDBatterySource {
    struct Result {
        var readings: [DeviceBattery] = []
        /// Kind of every connected HID device by name, used to label Bluetooth LE readings.
        var kinds: [String: DeviceBattery.Kind] = [:]
        var needsInputMonitoring = false
    }

    var onDevicesChanged: (() -> Void)?

    private let queue = DispatchQueue(label: "BluetoothBatteryBar.hid")
    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

    func start() {
        IOHIDManagerSetDeviceMatching(manager, nil)

        let context = Unmanaged.passUnretained(self).toOpaque()
        let changed: IOHIDDeviceCallback = { context, _, _, _ in
            let source = Unmanaged<HIDBatterySource>.fromOpaque(context!).takeUnretainedValue()
            DispatchQueue.main.async { source.onDevicesChanged?() }
        }
        IOHIDManagerRegisterDeviceMatchingCallback(manager, changed, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, changed, context)
        IOHIDManagerSetDispatchQueue(manager, queue)
        IOHIDManagerActivate(manager)
    }

    /// Reads off the main thread, since a Bluetooth request can take a moment.
    func read(completion: @escaping (Result) -> Void) {
        queue.async { [self] in
            let result = readDevices()
            DispatchQueue.main.async { completion(result) }
        }
    }

    private func readDevices() -> Result {
        var result = Result()
        // Without Input Monitoring, macOS hides the elements of keyboards, battery included.
        result.needsInputMonitoring = !InputMonitoring.isGranted
        let devices = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []

        // A device shows up once per HID interface, so readings are keyed by name.
        for device in devices {
            guard let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String else { continue }
            let kind = Self.kind(of: device, named: name)
            if result.kinds[name] == nil || result.kinds[name] == .other { result.kinds[name] = kind }

            guard !result.readings.contains(where: { $0.name == name }),
                  let element = Self.batteryElement(of: device) else { continue }

            let opened = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
            guard opened == kIOReturnSuccess else {
                log.error("opening \(name, privacy: .public) failed: \(String(format: "0x%x", opened), privacy: .public)")
                continue
            }
            defer { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }

            if let percent = Self.requestPercent(from: device, element: element) {
                // Kept in the system log so a device dropping its connection can be matched against reads.
                log.notice("read \(name, privacy: .public): \(percent)%")
                result.readings.append(DeviceBattery(id: "hid:\(name)", name: name, part: nil, kind: kind, percent: percent,
                                                     isCharging: nil, via: Self.via(device), updated: Date()))
            } else {
                log.debug("reading battery of \(name, privacy: .public) failed")
            }
        }
        return result
    }

    private static func via(_ device: IOHIDDevice) -> String {
        switch IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String {
        case "Bluetooth": "Bluetooth HID"
        case "Bluetooth Low Energy": "Bluetooth LE HID"
        case "USB": "USB HID"
        case let transport?: "\(transport) HID"
        case nil: "HID"
        }
    }

    /// The name decides first: mice often carry a keyboard interface for their extra buttons.
    private static func kind(of device: IOHIDDevice, named name: String) -> DeviceBattery.Kind {
        let guess = DeviceBattery.Kind(guessingFrom: name)
        guard guess == .other,
              IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsagePageKey as CFString) as? Int == kHIDPage_GenericDesktop else { return guess }
        switch IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsageKey as CFString) as? Int {
        case kHIDUsage_GD_Keyboard, kHIDUsage_GD_Keypad: return .keyboard
        case kHIDUsage_GD_Mouse, kHIDUsage_GD_Pointer: return .mouse
        case kHIDUsage_GD_GamePad, kHIDUsage_GD_Joystick, kHIDUsage_GD_MultiAxisController: return .gamepad
        default: return .other
        }
    }

    private static func batteryElement(of device: IOHIDDevice) -> IOHIDElement? {
        let matching = [kIOHIDElementUsagePageKey: batteryStrengthUsagePage, kIOHIDElementUsageKey: batteryStrengthUsage] as CFDictionary
        return (IOHIDDeviceCopyMatchingElements(device, matching, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement])?.first
    }

    private static func requestPercent(from device: IOHIDDevice, element: IOHIDElement) -> Int? {
        let placeholder = IOHIDValueCreateWithIntegerValue(kCFAllocatorDefault, element, 0, 0)
        var value = Unmanaged.passUnretained(placeholder)
        let status = withExtendedLifetime(placeholder) {
            IOHIDDeviceGetValueWithOptions(device, element, &value, getValueWithUpdate)
        }
        guard status == kIOReturnSuccess else { return nil }

        let raw = IOHIDValueGetIntegerValue(value.takeUnretainedValue())
        let min = IOHIDElementGetLogicalMin(element)
        let max = IOHIDElementGetLogicalMax(element)
        guard max > min else { return nil }
        return Swift.min(100, Swift.max(0, (raw - min) * 100 / (max - min)))
    }
}
