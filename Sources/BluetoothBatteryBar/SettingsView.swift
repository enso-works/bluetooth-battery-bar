import Combine
import SwiftUI

/// Hosts the settings view in a plain AppKit window, which a menu bar app can bring to front reliably.
final class SettingsWindow {
    static let shared = SettingsWindow()

    private var window: NSWindow?

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            window.title = "Bluetooth Battery Bar"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    /// Grow to fit all content instead of scrolling. Used when rendering README screenshots.
    var fitsContent = false

    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var monitor = BatteryMonitor.shared
    @ObservedObject private var updates = UpdateChecker.shared
    @State private var launchAtLogin = LoginItem.isEnabled

    /// Picks up a permission granted in System Settings while this window is open.
    private let permissionTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    private let repoURL = URL(string: "https://github.com/enso-works/bluetooth-battery-bar")!

    /// Tall enough for most sections, short enough for a 13-inch screen; the form scrolls beyond it.
    private var windowHeight: CGFloat {
        min(760, (NSScreen.main?.visibleFrame.height ?? 800) - 60)
    }

    var body: some View {
        form
            .frame(width: 500, height: fitsContent ? nil : windowHeight)
            .fixedSize(horizontal: false, vertical: fitsContent)
            .onAppear {
                launchAtLogin = LoginItem.isEnabled
                refreshPermissions()
            }
            .onReceive(permissionTimer) { _ in refreshPermissions() }
    }

    private func refreshPermissions() {
        // Screenshots show demo permission states, not the renderer's own.
        #if !SCREENSHOTS
        monitor.refreshPermissions()
        #endif
    }

    private var form: some View {
        Form {
            Section {
                HeaderRow()
                InputMonitoringRow(isGranted: !monitor.needsInputMonitoring)
                if monitor.bluetoothStatus == .denied || monitor.bluetoothStatus == .off {
                    BluetoothRow(status: monitor.bluetoothStatus)
                }
            }

            if let update = updates.availableUpdate {
                Section {
                    UpdateBanner(version: update.version, url: update.url)
                }
            }

            Section {
                if monitor.devices.isEmpty {
                    Text("No devices are reporting a battery level right now. A keyboard or mouse that is asleep or switched off doesn't show up until it reconnects.")
                        .foregroundStyle(.secondary)
                }
                ForEach(monitor.devices) { device in
                    DeviceRow(device: device, lowBatteryPercent: settings.lowBatteryPercent, isShown: Binding(
                        get: { !settings.hiddenDevices.contains(device.id) },
                        set: { settings.setHidden(!$0, deviceID: device.id) }
                    ))
                }
            } header: {
                HStack {
                    Text("Devices")
                    Spacer()
                    Button("Refresh") { monitor.refresh() }
                        .buttonStyle(.borderless)
                        .font(.callout)
                }
            } footer: {
                Text("Hidden devices are left out of the menu bar and alerts. Missing a device? See [supported devices](https://github.com/enso-works/bluetooth-battery-bar#supported-devices).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("General") {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        LoginItem.setEnabled(newValue)
                        launchAtLogin = LoginItem.isEnabled
                    }
                ))
                Picker("Menu bar shows", selection: $settings.menuBarShows) {
                    Text("Lowest battery").tag(AppSettings.showLowest)
                    ForEach(monitor.visibleDevices) { device in
                        Text(device.displayName).tag(device.id)
                    }
                    // Keeps the choice while that device is asleep; the menu bar shows the lowest meanwhile.
                    if isChosenDeviceMissing {
                        Text("A device that isn't connected").tag(settings.menuBarShows)
                    }
                    Text("Icon only").tag(AppSettings.showIconOnly)
                }
            }

            Section {
                Toggle("Notify when a battery runs low", isOn: $settings.notifyLowBattery)
                LabeledContent("Low battery at") {
                    HStack {
                        Slider(value: Binding(
                            get: { Double(settings.lowBatteryPercent) },
                            set: { settings.lowBatteryPercent = Int($0) }
                        ), in: AppSettings.lowBatteryRange, step: 5)
                        Text("\(settings.lowBatteryPercent)%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            } header: {
                Text("Low battery")
            } footer: {
                Text("At this level the menu bar number turns red. You get one notification per device, and the next one only after it has been charged.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Check for updates automatically", isOn: $settings.checkForUpdates)
                    .onChange(of: settings.checkForUpdates) { enabled in
                        if enabled { updates.check() }
                    }
                HStack {
                    UpdateStatus(state: updates.state)
                    Spacer()
                    Button("Check Now") { updates.check() }
                        .disabled(updates.state == .checking)
                }
            } header: {
                Text("Updates")
            } footer: {
                Text("When on, the app asks GitHub for the latest version once a day. Nothing about you or your Mac is sent. It never downloads or installs anything by itself.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Text("Version \(UpdateChecker.currentVersion)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Link("GitHub", destination: repoURL)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var isChosenDeviceMissing: Bool {
        let choice = settings.menuBarShows
        return choice != AppSettings.showLowest && choice != AppSettings.showIconOnly
            && !monitor.visibleDevices.contains { $0.id == choice }
    }
}

private struct DeviceRow: View {
    let device: DeviceBattery
    let lowBatteryPercent: Int
    @Binding var isShown: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: device.kind.symbolName)
                .frame(width: 22)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .lineLimit(1)
                Text(device.via)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if device.isCharging == true {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Charging")
            }
            Text("\(device.percent)%")
                .monospacedDigit()
                .foregroundStyle(device.isLow(threshold: lowBatteryPercent) ? Color.red : Color.primary)
            Toggle("Show \(device.displayName)", isOn: $isShown)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .opacity(isShown ? 1 : 0.55)
    }
}

private struct UpdateBanner: View {
    let version: String
    let url: URL

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Version \(version) is available")
                    .font(.headline)
                Text("You have \(UpdateChecker.currentVersion).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Download") { NSWorkspace.shared.open(url) }
                .keyboardShortcut(.defaultAction)
        }
    }
}

private struct UpdateStatus: View {
    let state: UpdateChecker.State

    var body: some View {
        switch state {
        case .idle:
            Text("Not checked yet").foregroundStyle(.secondary)
        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Checking...").foregroundStyle(.secondary)
            }
        case .upToDate:
            Label("You're up to date", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
        case .available(let version, _):
            Label("Version \(version) available", systemImage: "arrow.down.circle.fill")
                .foregroundStyle(Color.accentColor)
        case .failed:
            Label("Couldn't reach GitHub", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.secondary)
        }
    }
}

private struct HeaderRow: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text("Bluetooth Battery Bar")
                    .font(.title3.weight(.semibold))
                Text("Battery levels macOS doesn't show you, in the menu bar.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct InputMonitoringRow: View {
    let isGranted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(isGranted ? .green : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isGranted ? "Input Monitoring allowed" : "Input Monitoring needed for keyboards")
                        .font(.headline)
                    Text(isGranted
                         ? "Bluetooth keyboards can be read."
                         : "macOS hides a keyboard's battery level from apps without it. The app only asks the keyboard for its battery level and never sees what you type.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            if !isGranted {
                Text("In Privacy & Security > Input Monitoring, turn this on, then choose Quit & Reopen:")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                SettingsToggleHint()
                HStack {
                    Spacer()
                    Button("Open Settings") {
                        InputMonitoring.request()
                        InputMonitoring.openSettings()
                    }
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
    }
}

private struct BluetoothRow: View {
    let status: BLEBatterySource.Status

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(status == .off ? "Bluetooth is off" : "Bluetooth access needed")
                    .font(.headline)
                Text(status == .off
                     ? "Turn Bluetooth on to see your devices."
                     : "Needed to read Bluetooth LE devices such as mice and headphones.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if status == .denied {
                Button("Open Settings") { BluetoothPermission.openSettings() }
            }
        }
    }
}

/// A picture of the row users need to switch on in System Settings.
private struct SettingsToggleHint: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 26, height: 26)
            Text("Bluetooth Battery Bar")
            Spacer()
            Capsule()
                .fill(Color.accentColor)
                .frame(width: 38, height: 22)
                .overlay(alignment: .trailing) {
                    Circle()
                        .fill(.white)
                        .padding(2)
                        .shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.25)))
        .accessibilityHidden(true)
    }
}
