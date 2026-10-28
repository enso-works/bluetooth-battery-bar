# KeyBattery

Menu bar app for macOS that shows the battery level of Bluetooth keyboards and mice, including the ones macOS itself shows no percentage for (such as the Keychron K2).

## What it can read

| Source | Devices | How |
|---|---|---|
| macOS | Magic Keyboard, Magic Mouse, Magic Trackpad | `BatteryPercent` in the IORegistry |
| Bluetooth HID | Classic Bluetooth devices declaring HID "Battery Strength" (usage page 0x06, usage 0x20), e.g. Keychron K-series | Requests the input report from the device |
| Bluetooth LE | Devices with the standard Battery Service (0x180F), e.g. Logitech MX in Bluetooth mode | CoreBluetooth, Battery Level characteristic (0x2A19) |

Not supported: Logitech Bolt/Unifying receivers (HID++), vendor 2.4 GHz dongles, wired keyboards.

## Build

```sh
./build.sh           # builds build/KeyBattery.app
./build.sh install   # also copies it to ~/Applications and launches it
build/KeyBattery.app/Contents/MacOS/KeyBattery --list   # print readings and exit
```

Requires the Xcode command line tools and macOS 14+, Apple Silicon.

## Permissions

- **Bluetooth**: asked on first launch, needed for Bluetooth LE devices.
- **Notifications**: for the low-battery alert (20% and below).
- **Input Monitoring**: needed for classic Bluetooth keyboards. Without it macOS hides every field of a keyboard, battery included; the menu then shows "Allow Input Monitoring…". The app only requests the battery report and never listens to key presses.

`build.sh` signs with your first "Apple Development" certificate (or `SIGN_IDENTITY`) so these permissions survive rebuilds. Without one it signs ad-hoc, and macOS asks again after every build.
