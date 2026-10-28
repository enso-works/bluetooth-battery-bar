import Foundation
import IOKit.hid
import os

private let log = Logger(subsystem: "dev.local.KeyBattery", category: "hid")
private let batteryStrengthUsagePage = 0x06
private let batteryStrengthUsage = 0x20
private let getValueWithUpdate: IOOptionBits = 0x0002_0000

/// Classic Bluetooth keyboards and mice that declare a HID "Battery Strength" field
/// (usage page 0x06, usage 0x20), such as the Keychron K-series. They only send the
/// value when asked, so every read requests a fresh report from the device.
final class HIDBatterySource {
    struct Result {
        var readings: [DeviceBattery] = []
        /// Kind of every connected keyboard or mouse by name, used to label Bluetooth LE readings.
        var kinds: [String: DeviceBattery.Kind] = [:]
        var needsInputMonitoring = false
    }

    var onDevicesChanged: (() -> Void)?

    private let queue = DispatchQueue(label: "KeyBattery.hid")
    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private var requestedInputMonitoring = false

    func start() {
        IOHIDManagerSetDeviceMatchingMultiple(manager, [
            [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard],
            [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Mouse],
        ] as CFArray)

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
            DispatchQueue.main.async { [self] in
                if result.needsInputMonitoring && !requestedInputMonitoring {
                    requestedInputMonitoring = true
                    IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
                }
                completion(result)
            }
        }
    }

    private func readDevices() -> Result {
        var result = Result()
        let devices = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []
        // Without Input Monitoring, macOS hides the elements of keyboards, battery included.
        result.needsInputMonitoring = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) != kIOHIDAccessTypeGranted

        // A device shows up once per HID interface, so readings are keyed by name.
        for device in devices {
            guard let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String else { continue }
            let kind = Self.kind(of: device, named: name)
            if result.kinds[name] != .mouse { result.kinds[name] = kind }

            guard !result.readings.contains(where: { $0.name == name }),
                  let element = Self.batteryElement(of: device) else { continue }

            let opened = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
            guard opened == kIOReturnSuccess else {
                log.error("opening \(name, privacy: .public) failed: \(String(format: "0x%x", opened), privacy: .public)")
                continue
            }
            defer { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }

            if let percent = Self.requestPercent(from: device, element: element) {
                result.readings.append(DeviceBattery(name: name, kind: kind, percent: percent, source: .hid, updated: Date()))
            } else {
                log.error("reading battery of \(name, privacy: .public) failed")
            }
        }
        return result
    }

    /// The name decides first: mice often carry a keyboard interface for their extra buttons.
    private static func kind(of device: IOHIDDevice, named name: String) -> DeviceBattery.Kind {
        let guess = DeviceBattery.Kind(guessingFrom: name)
        guard guess == .other,
              IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsagePageKey as CFString) as? Int == kHIDPage_GenericDesktop else { return guess }
        switch IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsageKey as CFString) as? Int {
        case kHIDUsage_GD_Keyboard: return .keyboard
        case kHIDUsage_GD_Mouse: return .mouse
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
