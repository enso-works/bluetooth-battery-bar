#!/bin/zsh
# Packages build/*.app into a drag-to-Applications DMG and a zip in dist/, with SHA256SUMS.txt.
# Writes both a versioned DMG and a stable-named copy for "latest" download links.
# Env: VERSION         defaults to ./VERSION
#      SIGN_IDENTITY   signs the DMG too (needed for notarization)
#      NOTARY_PROFILE  notarizes and staples with this `xcrun notarytool store-credentials` profile
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-$(cat VERSION)}"
APP="build/Bluetooth Battery Bar.app"
STAGING="build/dmg"
NAME="BluetoothBatteryBar"
DMG="dist/$NAME-$VERSION.dmg"
ZIP="dist/$NAME-$VERSION.zip"

notarize() {
  echo "Notarizing $(basename "$1")"
  xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait
}

# The ticket lookup behind stapler can fail on CI runners or lag behind notarization, so retry it.
# Usage: stapler staple|validate <path>
stapler() {
  local attempt
  for attempt in 1 2 3 4 5; do
    xcrun stapler "$1" "$2" && return 0
    echo "stapler $1 $(basename "$2") failed (attempt $attempt), retrying in $((attempt * 15))s"
    sleep $((attempt * 15))
  done
  xcrun stapler "$1" "$2"
}

rm -rf "$STAGING" dist
mkdir -p "$STAGING" dist

# The app is notarized through a zip; stapling then lets it open offline.
ditto -c -k --keepParent "$APP" "$ZIP"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  notarize "$ZIP"
  stapler staple "$APP"
  rm -f "$ZIP"
  ditto -c -k --keepParent "$APP" "$ZIP"
fi

cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
# hdiutil fails now and then on CI runners with "Resource busy", so retry it.
for attempt in 1 2 3 4; do
  hdiutil create -volname "Bluetooth Battery Bar" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null && break
  [[ $attempt -eq 4 ]] && exit 1
  echo "hdiutil create failed (attempt $attempt), retrying in $((attempt * 10))s"
  sleep $((attempt * 10))
done

if [[ -n "${SIGN_IDENTITY:-}" && "$SIGN_IDENTITY" != "-" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
fi
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  notarize "$DMG"
  stapler staple "$DMG"
  echo "Checking Gatekeeper"
  stapler validate "$APP"
  stapler validate "$DMG"
  spctl --assess --type execute --verbose "$APP"
  spctl --assess --type open --context context:primary-signature --verbose "$DMG"
fi

cp "$DMG" "dist/$NAME.dmg"
(cd dist && shasum -a 256 *.dmg *.zip > SHA256SUMS.txt)
ls -lh dist
