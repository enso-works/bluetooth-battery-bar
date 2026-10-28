# Changelog

## 1.0.0

The first release: the battery level of keyboards, mice and controllers that macOS doesn't show, in the menu bar.

- **Bluetooth keyboards** that report HID "Battery Strength", such as the Keychron K-series.
- **Bluetooth LE devices** with the standard battery service: mice, headphones, and split keyboards with each half on its own.
- **Game controllers** through Apple's GameController framework, with charging.
- **Apple devices** with macOS's own value, shown alongside.
- **Low battery alerts:** the menu bar number turns red and you get one notification per device. The level is adjustable, 20% by default.
- **Hide devices**, pin one device to the menu bar, or show only the icon.
- Launch at login and an optional, off-by-default update check.

**Install:** open the DMG and drag the app onto Applications, or run `brew install --cask enso-works/tap/bluetooth-battery-bar`. Universal build for Apple Silicon and Intel, macOS 13 Ventura or later, signed and notarized.

**First launch:** allow Bluetooth and notifications when asked. For Bluetooth keyboards, turn on Bluetooth Battery Bar in **System Settings > Privacy & Security > Input Monitoring**, then choose Quit & Reopen.

Vendor protocols such as Logitech receivers and gaming headsets aren't supported yet; see [docs/vendor-protocols.md](https://github.com/enso-works/bluetooth-battery-bar/blob/main/docs/vendor-protocols.md).
