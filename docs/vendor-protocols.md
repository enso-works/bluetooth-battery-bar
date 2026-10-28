# Vendor protocols

Version 1.0 reads battery levels only through standard interfaces: HID "Battery Strength", the Bluetooth LE Battery Service, Apple's GameController framework and macOS's own value for Apple devices. Many devices report their battery only through their maker's own protocol, mostly over a USB receiver. **None of these is supported yet.** This list is the plan for later versions.

| Vendor | Devices | Connection | Protocol | Open-source reference (license) |
| --- | --- | --- | --- | --- |
| Logitech | MX Keys, MX Master, MX Anywhere, K and M series, G wireless | Bolt, Unifying and Lightspeed receivers, Bluetooth | HID++ 2.0, battery features `0x1000` (level status), `0x1001` (voltage), `0x1004` (unified battery) | [Solaar](https://github.com/pwr-Solaar/Solaar) (GPL-2.0), [libratbag](https://github.com/libratbag/libratbag) (MIT), [logiops](https://github.com/PixlOne/logiops) (GPL-3.0) |
| Logitech G | G-series wireless headsets | Lightspeed receiver | Vendor HID reports | [HeadsetControl](https://github.com/Sapd/HeadsetControl) (GPL-3.0) |
| SteelSeries | Arctis headsets | USB receiver | Vendor HID reports | [HeadsetControl](https://github.com/Sapd/HeadsetControl) (GPL-3.0) |
| Corsair | Void and HS headsets, wireless mice and keyboards | Slipstream receiver | Vendor HID reports | [HeadsetControl](https://github.com/Sapd/HeadsetControl) (GPL-3.0), [ckb-next](https://github.com/ckb-next/ckb-next) (GPL-2.0) |
| HyperX | Cloud wireless headsets | USB receiver | Vendor HID reports | [HeadsetControl](https://github.com/Sapd/HeadsetControl) (GPL-3.0) |
| Razer | Wireless mice and keyboards | HyperSpeed receiver | Razer's report protocol | [OpenRazer](https://github.com/openrazer/openrazer) (GPL-2.0) |
| Keychron | Pro, Max and Q series in 2.4 GHz mode | Keychron Link receiver | Unknown | None known |

## Also planned, not vendor-specific

- **Devices that only push their battery level.** Some devices declare HID "Battery Strength" but don't answer a request for it; they send it on their own now and then. Supporting them means keeping the device open and listening for that one value.

## Not possible

- **Devices that never report a level.** Many inexpensive 2.4 GHz mice and keyboards, such as the HP 250/255 USB receiver, have no battery field at all. There is nothing to read.

## Adding one

Each protocol would be one more source next to the existing ones in `Sources/BluetoothBatteryBar/`, picked by USB vendor ID, talking to the device through IOKit HID reports. Write it from protocol documentation and your own testing: code from the GPL projects above can't be copied into this MIT-licensed project. Please open an issue first, and say which device you can test with.
