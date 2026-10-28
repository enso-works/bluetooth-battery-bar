#!/bin/zsh
# Builds a universal (Apple Silicon + Intel) app bundle into build/.
# Env: VERSION        defaults to ./VERSION
#      SIGN_IDENTITY  defaults to your first "Apple Development" certificate, else ad-hoc ("-").
#                     Releases use "Developer ID Application: ...".
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-$(cat VERSION)}"
APP="build/Bluetooth Battery Bar.app"
ICONSET="build/AppIcon.iconset"
ARCHS=(--arch arm64 --arch x86_64)

# A stable identity keeps macOS permissions (Input Monitoring, Bluetooth) across rebuilds;
# ad-hoc signing gives every build a new identity.
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning | grep -m1 -o '"Apple Development[^"]*"' | tr -d '"' || true)"
fi
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

swift build -c release "${ARCHS[@]}"
BIN_DIR="$(swift build -c release "${ARCHS[@]}" --show-bin-path)"

rm -rf "$APP" "$ICONSET"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ICONSET"
cp "$BIN_DIR/BluetoothBatteryBar" "$APP/Contents/MacOS/"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"

for size in 16 32 128 256 512; do
  sips -z $size $size Resources/AppIcon-1024.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) Resources/AppIcon-1024.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

# Notarization needs a secure timestamp, which only a real identity can get.
SIGN=(codesign --force --options runtime --sign "$SIGN_IDENTITY")
[[ "$SIGN_IDENTITY" != "-" ]] && SIGN+=(--timestamp)
"${SIGN[@]}" "$APP"
codesign --verify --strict "$APP"
echo "Built $APP ($VERSION, signed with: $SIGN_IDENTITY)"
