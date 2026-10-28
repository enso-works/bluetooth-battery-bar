import CoreBluetooth

/// Bluetooth LE keyboards and mice that expose the standard Battery Service (0x180F).
/// macOS keeps them connected; the app attaches to that connection and reads Battery Level (0x2A19).
final class BLEBatterySource: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private static let batteryService = CBUUID(string: "180F")
    private static let batteryLevel = CBUUID(string: "2A19")

    var onChange: (() -> Void)?

    private var central: CBCentralManager!
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var levels: [UUID: (percent: Int, updated: Date)] = [:]

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func readings(knownKinds: [String: DeviceBattery.Kind]) -> [DeviceBattery] {
        peripherals.values.compactMap { peripheral in
            guard peripheral.state == .connected,
                  let name = peripheral.name,
                  let level = levels[peripheral.identifier] else { return nil }
            // Only input devices: phones, watches and headphones expose a battery service too.
            let kind = knownKinds[name] ?? DeviceBattery.Kind(guessingFrom: name)
            guard kind != .other else { return nil }
            return DeviceBattery(name: name, kind: kind, percent: level.percent, source: .ble, updated: level.updated)
        }
    }

    func refresh() {
        guard central.state == .poweredOn else { return }
        for peripheral in central.retrieveConnectedPeripherals(withServices: [Self.batteryService])
        where peripherals[peripheral.identifier] == nil {
            peripheral.delegate = self
            peripherals[peripheral.identifier] = peripheral
        }
        for peripheral in peripherals.values {
            switch peripheral.state {
            case .connected: readLevel(of: peripheral)
            // Waits until the device is back; macOS reconnects it on its own.
            case .disconnected: central.connect(peripheral)
            default: break
            }
        }
    }

    private func readLevel(of peripheral: CBPeripheral) {
        let characteristic = peripheral.services?
            .first { $0.uuid == Self.batteryService }?
            .characteristics?.first { $0.uuid == Self.batteryLevel }
        if let characteristic {
            peripheral.readValue(for: characteristic)
        } else {
            peripheral.discoverServices([Self.batteryService])
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        refresh()
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([Self.batteryService])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        levels[peripheral.identifier] = nil
        onChange?()
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] where service.uuid == Self.batteryService {
            peripheral.discoverCharacteristics([Self.batteryLevel], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics ?? [] where characteristic.uuid == Self.batteryLevel {
            peripheral.readValue(for: characteristic)
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == Self.batteryLevel, let byte = characteristic.value?.first else { return }
        levels[peripheral.identifier] = (min(Int(byte), 100), Date())
        onChange?()
    }
}
