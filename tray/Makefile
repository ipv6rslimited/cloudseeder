##
##
## Makefile
## Provides a Makefile for Cloud Seeder tray by IPv6rs
##
## Distributed under the COOLER License.
##
## Copyright (c) 2024 IPv6.rs <https://ipv6.rs>
## All Rights Reserved
##
##
.PHONY: all build-darwin build-windows build-linux clean
OUTPUT_DIR := ./dist
$(shell mkdir -p $(OUTPUT_DIR))
NAME=Cloud Seeder Tray
BINARY_NAME=tray
APP_ID=com.ipv6rs.cloudseedertray
SHORT_NAME:=$(shell echo ${APP_ID} | awk -F '.' '{print $$3}')

all: darwin linux-x86 linux-arm windows-x86 windows-arm

darwin:
	@mkdir -p $(OUTPUT_DIR)/macos/
	@fyne-cross darwin -arch=arm64 -app-id="${APP_ID}" -name="${NAME}" .
	@fyne-cross darwin -arch=amd64 -app-id="${APP_ID}" -name="${NAME}" .
	@cp "fyne-cross/dist/darwin-amd64/${NAME}.app/Contents/MacOS/cloudseeder-monitor" "dist/cloudseeder-monitor-macos-amd64"
	@cp "fyne-cross/dist/darwin-arm64/${NAME}.app/Contents/MacOS/cloudseeder-monitor" "dist/cloudseeder-monitor-macos-arm64"


windows-x86:
	@mkdir -p $(OUTPUT_DIR)/windows-x86/
	@fyne-cross windows -arch=amd64 -app-id="${APP_ID}" -name="${NAME}" .
	@unzip "fyne-cross/dist/windows-amd64/${NAME}.zip" -d fyne-cross/dist/windows-amd64/ > /dev/null 2>&1
	@cp "fyne-cross/dist/windows-amd64/${NAME}.exe" "dist/cloudseeder-monitor-windows-amd64.exe"

windows-arm:
	@mkdir -p $(OUTPUT_DIR)/windows-arm/
	@fyne-cross windows -arch=arm64 -app-id="${APP_ID}" -name="${NAME}" .
	@unzip "fyne-cross/dist/windows-arm64/${NAME}.zip" -d fyne-cross/dist/windows-arm64/ > /dev/null 2>&1
	@cp "fyne-cross/dist/windows-arm64/${NAME}.exe" "dist/cloudseeder-monitor-windows-arm64.exe"

linux-x86:
	@mkdir -p $(OUTPUT_DIR)/linux-x86/
	@fyne-cross linux -arch=amd64 -app-id="${APP_ID}" -name="${NAME}" .
	@tar -xf "fyne-cross/dist/linux-amd64/${NAME}.tar.xz" -C fyne-cross/dist/linux-amd64/
	@cp -R "fyne-cross/dist/linux-amd64/usr/local/bin/cloudseeder-monitor" "dist/cloudseeder-monitor-linux-amd64"

linux-arm:
	@mkdir -p $(OUTPUT_DIR)/linux-arm/
	@fyne-cross linux -arch=arm64 -app-id="${APP_ID}" -name="${NAME}" .
	@tar -xf "fyne-cross/dist/linux-arm64/${NAME}.tar.xz" -C fyne-cross/dist/linux-arm64/
	@cp -R "fyne-cross/dist/linux-arm64/usr/local/bin/cloudseeder-monitor" "dist/cloudseeder-monitor-linux-arm64"

clean:
	rm -rf $(OUTPUT_DIR)
	rm -rf fyne-cross

