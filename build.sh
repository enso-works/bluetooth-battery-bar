#!/bin/bash
# Builds build/KeyBattery.app. Pass "install" to copy it to ~/Applications and launch it.
set -euo pipefail
cd "$(dirname "$0")"

APP=build/KeyBattery.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -swift-version 5 -target arm64-apple-macos14.0 Sources/*.swift -o "$APP/Contents/MacOS/KeyBattery"
cp Resources/Info.plist "$APP/Contents/"

# A real identity keeps macOS permissions (Input Monitoring, Bluetooth) across rebuilds;
# ad-hoc signing gives every build a new identity. Override with SIGN_IDENTITY.
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | grep -m1 -o '"Apple Development[^"]*"' | tr -d '"' || true)}"
codesign --force --sign "${IDENTITY:--}" "$APP"
echo "Signed with ${IDENTITY:-ad-hoc identity}"
echo "Built $APP"

if [[ "${1:-}" == "install" ]]; then
    pkill -x KeyBattery || true
    while pgrep -x KeyBattery > /dev/null; do sleep 0.2; done
    mkdir -p ~/Applications
    rm -rf ~/Applications/KeyBattery.app
    cp -R "$APP" ~/Applications/
    open ~/Applications/KeyBattery.app
    echo "Installed ~/Applications/KeyBattery.app"
fi
