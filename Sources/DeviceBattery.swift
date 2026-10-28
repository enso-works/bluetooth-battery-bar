import Foundation

/// One battery reading for a connected keyboard, mouse or trackpad.
struct DeviceBattery {
    enum Kind {
        case keyboard, mouse, trackpad, other

        init(guessingFrom name: String) {
            let name = name.lowercased()
            if name.contains("keyboard") || name.contains("keys") {
                self = .keyboard
            } else if name.contains("trackpad") {
                self = .trackpad
            } else if name.contains("mouse") || name.contains("mx master") || name.contains("mx anywhere") {
                self = .mouse
            } else {
                self = .other
            }
        }

        var symbolName: String {
            switch self {
            case .keyboard: "keyboard"
            case .mouse: "computermouse"
            case .trackpad: "rectangle.and.hand.point.up.left"
            case .other: "dot.radiowaves.left.and.right"
            }
        }

        var sortOrder: Int {
            switch self {
            case .keyboard: 0
            case .mouse: 1
            case .trackpad: 2
            case .other: 3
            }
        }
    }

    enum Source: String {
        case system = "macOS"
        case hid = "Bluetooth HID"
        case ble = "Bluetooth LE"
    }

    let name: String
    let kind: Kind
    let percent: Int
    let source: Source
    let updated: Date
}
