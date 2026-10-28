cask "bluetooth-battery-bar" do
  version "__VERSION__"
  sha256 "__SHA256__"

  url "https://github.com/enso-works/bluetooth-battery-bar/releases/download/v#{version}/BluetoothBatteryBar-#{version}.dmg"
  name "Bluetooth Battery Bar"
  desc "Menu bar battery levels for Bluetooth keyboards, mice and controllers"
  homepage "https://github.com/enso-works/bluetooth-battery-bar"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :ventura"

  app "Bluetooth Battery Bar.app"

  uninstall quit: "works.enso.BluetoothBatteryBar"

  zap trash: "~/Library/Preferences/works.enso.BluetoothBatteryBar.plist"
end
