// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BluetoothBatteryBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "BluetoothBatteryBar",
            path: "Sources/BluetoothBatteryBar"
        )
    ]
)
