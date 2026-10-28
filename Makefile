APP := build/Bluetooth Battery Bar.app
VERSION ?= $(shell cat VERSION)

.PHONY: app install dmg art screenshots list clean

## Build the universal app bundle into build/
app:
	VERSION=$(VERSION) ./scripts/build-app.sh

## Build, copy the app to /Applications and start it
install: app
	-pkill -x BluetoothBatteryBar
	@while pgrep -x BluetoothBatteryBar >/dev/null; do sleep 0.2; done
	rm -rf "/Applications/Bluetooth Battery Bar.app"
	cp -R "$(APP)" /Applications/
	open "/Applications/Bluetooth Battery Bar.app"
	@echo "Installed to /Applications."

## Build and package the release DMG and zip into dist/
dmg: app
	VERSION=$(VERSION) ./scripts/package-dmg.sh

## Re-render the icon and README artwork
art:
	swift scripts/generate-art.swift

## Re-render the settings window screenshots
screenshots:
	./scripts/render-screenshots.sh

## Print the battery levels the app can read right now
list: app
	"$(APP)/Contents/MacOS/BluetoothBatteryBar" --list

clean:
	rm -rf .build build dist
