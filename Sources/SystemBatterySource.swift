import Foundation
import IOKit

/// Devices macOS already tracks itself, such as the Magic Keyboard, Magic Mouse and Magic Trackpad.
enum SystemBatterySource {
    static func read() -> [DeviceBattery] {
        var iterator = io_iterator_t()
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleDeviceManagementHIDEventService"), &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var readings: [DeviceBattery] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            guard let percent = property(service, "BatteryPercent") as? Int,
                  let name = property(service, "Product") as? String else { continue }
            readings.append(DeviceBattery(name: name, kind: .init(guessingFrom: name), percent: percent, source: .system, updated: Date()))
        }
        return readings
    }

    private static func property(_ service: io_object_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}
