import CoreBluetooth

/// Bluetooth LE devices that expose the standard Battery Service (0x180F): mice, headphones,
/// split keyboards and more. macOS keeps them connected; the app attaches to that connection and
/// reads every Battery Level characteristic (0x2A19), so a split keyboard shows each half.
final class BLEBatterySource: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    enum Status {
        case unknown, ready, off, denied
    }

    private static let batteryService = CBUUID(string: "180F")
    private static let batteryLevel = CBUUID(string: "2A19")
    private static let userDescription = CBUUID(string: CBUUIDCharacteristicUserDescriptionString)

    var onChange: (() -> Void)?

    private var central: CBCentralManager?
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var levels: [ObjectIdentifier: (percent: Int, updated: Date)] = [:]
    private var labels: [ObjectIdentifier: String] = [:]

    var status: Status {
        switch CBManager.authorization {
        case .denied, .restricted: return .denied
        case .notDetermined: return .unknown
        default: break
        }
        switch central?.state {
        case .poweredOn: return .ready
        case .poweredOff: return .off
        case .unauthorized: return .denied
        default: return .unknown
        }
    }

    func start() {
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func readings(knownKinds: [String: DeviceBattery.Kind]) -> [DeviceBattery] {
        peripherals.values.filter { $0.state == .connected }.flatMap { peripheral -> [DeviceBattery] in
            guard let name = peripheral.name else { return [] }
            let kind = knownKinds[name] ?? DeviceBattery.Kind(guessingFrom: name)
            let characteristics = batteryCharacteristics(of: peripheral)
            return characteristics.enumerated().compactMap { index, characteristic in
                guard let level = levels[ObjectIdentifier(characteristic)] else { return nil }
                let part = labels[ObjectIdentifier(characteristic)] ?? (characteristics.count > 1 ? "Battery \(index + 1)" : nil)
                return DeviceBattery(id: "ble:\(name)" + (part.map { ":\($0)" } ?? ""), name: name, part: part, kind: kind,
                                     percent: level.percent, isCharging: nil, via: "Bluetooth LE", updated: level.updated)
            }
        }
    }

    func refresh() {
        guard let central, central.state == .poweredOn else { return }
        for peripheral in central.retrieveConnectedPeripherals(withServices: [Self.batteryService])
        where peripherals[peripheral.identifier] == nil {
            peripheral.delegate = self
            peripherals[peripheral.identifier] = peripheral
        }
        for peripheral in peripherals.values {
            switch peripheral.state {
            case .connected:
                let characteristics = batteryCharacteristics(of: peripheral)
                if characteristics.isEmpty {
                    peripheral.discoverServices([Self.batteryService])
                }
                characteristics.forEach { peripheral.readValue(for: $0) }
            // Waits until the device is back; macOS reconnects it on its own.
            case .disconnected: central.connect(peripheral)
            default: break
            }
        }
    }

    private func batteryCharacteristics(of peripheral: CBPeripheral) -> [CBCharacteristic] {
        (peripheral.services ?? [])
            .filter { $0.uuid == Self.batteryService }
            .flatMap { $0.characteristics ?? [] }
            .filter { $0.uuid == Self.batteryLevel }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        refresh()
        onChange?()
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([Self.batteryService])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
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
            peripheral.discoverDescriptors(for: characteristic)
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == Self.batteryLevel, let byte = characteristic.value?.first else { return }
        levels[ObjectIdentifier(characteristic)] = (min(Int(byte), 100), Date())
        onChange?()
    }

    // A "Characteristic User Description" names the battery, e.g. the other half of a split keyboard.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        for descriptor in characteristic.descriptors ?? [] where descriptor.uuid == Self.userDescription {
            peripheral.readValue(for: descriptor)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        guard descriptor.uuid == Self.userDescription, let characteristic = descriptor.characteristic,
              let label = descriptor.value as? String, !label.isEmpty else { return }
        labels[ObjectIdentifier(characteristic)] = label
        onChange?()
    }
}
