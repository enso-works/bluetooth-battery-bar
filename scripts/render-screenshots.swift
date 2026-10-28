// Renders the real settings view to PNGs for the README, in light and dark mode, with demo devices.
// Compiled together with the app sources (minus App.swift) by scripts/render-screenshots.sh.

import AppKit
import SwiftUI

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.applicationIconImage = NSImage(contentsOfFile: "Resources/AppIcon-1024.png")
app.activate(ignoringOtherApps: true)

let now = Date()
let demoDevices = [
    DeviceBattery(id: "hid:Keychron K2", name: "Keychron K2", part: nil, kind: .keyboard, percent: 56,
                  isCharging: nil, via: "Bluetooth HID", updated: now),
    DeviceBattery(id: "ble:HP 250/255 Dual Mouse", name: "HP 250/255 Dual Mouse", part: nil, kind: .mouse, percent: 88,
                  isCharging: nil, via: "Bluetooth LE", updated: now),
    DeviceBattery(id: "controller:DualSense Wireless Controller", name: "DualSense Wireless Controller", part: nil, kind: .gamepad,
                  percent: 18, isCharging: false, via: "Game controller", updated: now),
]

func renderSettings(inputMonitoring: Bool, appearance: NSAppearance.Name, to path: String) {
    BatteryMonitor.shared.showDemo(demoDevices, needsInputMonitoring: !inputMonitoring)
    let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(fitsContent: true)))
    window.title = "Bluetooth Battery Bar"
    window.styleMask = [.titled, .closable]
    window.appearance = NSAppearance(named: appearance)
    window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
    window.makeKeyAndOrderFront(nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.6))

    // The theme frame includes the title bar, so the image looks like a real window.
    let view = window.contentView!.superview!
    let scale: CGFloat = 2
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: Int(view.bounds.width * scale), pixelsHigh: Int(view.bounds.height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = view.bounds.size
    view.cacheDisplay(in: view.bounds, to: rep)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    window.close()
    print("wrote \(path)")
}

for (appearance, suffix) in [(NSAppearance.Name.darkAqua, "dark"), (.aqua, "light")] {
    renderSettings(inputMonitoring: true, appearance: appearance, to: "docs/images/settings-\(suffix).png")
    renderSettings(inputMonitoring: false, appearance: appearance, to: "docs/images/permission-\(suffix).png")
}
