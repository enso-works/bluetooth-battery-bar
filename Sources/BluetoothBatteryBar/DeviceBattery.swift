import Foundation

/// One battery reading for a connected device, or for one part of it (a split keyboard half).
struct DeviceBattery: Identifiable, Equatable {
    enum Kind: String {
        case keyboard, mouse, trackpad, gamepad, headphones, other

        init(guessingFrom name: String) {
            let name = name.lowercased()
            func has(_ words: String...) -> Bool { words.contains { name.contains($0) } }
            if has("keyboard", "keys") {
                self = .keyboard
            } else if has("trackpad") {
                self = .trackpad
            } else if has("mouse", "mx master", "mx anywhere", "trackball") {
                self = .mouse
            } else if has("controller", "gamepad", "dualsense", "dualshock", "xbox", "joy-con") {
                self = .gamepad
            } else if has("headphone", "headset", "earbuds", "buds") {
                self = .headphones
            } else {
                self = .other
            }
        }

        var symbolName: String {
            switch self {
            case .keyboard: "keyboard"
            case .mouse: "computermouse"
            case .trackpad: "rectangle.and.hand.point.up.left"
            case .gamepad: "gamecontroller"
            case .headphones: "headphones"
            case .other: "dot.radiowaves.left.and.right"
            }
        }

        var sortOrder: Int {
            switch self {
            case .keyboard: 0
            case .mouse: 1
            case .trackpad: 2
            case .gamepad: 3
            case .headphones: 4
            case .other: 5
            }
        }
    }

    /// Stable across reconnects and relaunches, so hidden devices and the menu bar choice stick.
    let id: String
    let name: String
    /// Which part of the device, when it reports more than one battery, e.g. "Left" or "Peripheral 0".
    let part: String?
    let kind: Kind
    let percent: Int
    /// nil when the device doesn't say.
    let isCharging: Bool?
    /// How the level was read, e.g. "Bluetooth HID".
    let via: String
    let updated: Date

    var displayName: String {
        part.map { "\(name) (\($0))" } ?? name
    }

    func isLow(threshold: Int) -> Bool {
        percent <= threshold && isCharging != true
    }
}
