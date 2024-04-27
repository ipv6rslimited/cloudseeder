##
##
## Makefile
## Provides a Makefile for Cloud Seeder by IPv6rs
##
## Distributed under the COOLER License.
##
## Copyright (c) 2024 IPv6.rs <https://ipv6.rs>
## All Rights Reserved
##
##
NAME=Cloud Seeder
BINARY_NAME=cloudseeder
APP_ID=com.ipv6rs.cloudseeder
SHORT_NAME:=$(shell echo ${APP_ID} | awk -F '.' '{print $$3}')
CURRENT_FOLDER:=$(shell basename "$$(pwd)")

all: darwin linux-x86 linux-arm windows-x86 windows-arm

darwin:
	@fyne-cross darwin -arch=amd64 -app-id=${APP_ID} -name="${NAME}" src/
	@fyne-cross darwin -arch=arm64 -app-id=${APP_ID} -name="${NAME}" src/

	@echo [i] Preparing Universal Package
	@rm -rf fyne-cross/dist/darwin-universal
	@cp -R fyne-cross/dist/darwin-arm64 fyne-cross/dist/darwin-universal
	@lipo -create -output "fyne-cross/dist/darwin-universal/${NAME}.app/Contents/MacOS/${SHORT_NAME}" "fyne-cross/dist/darwin-arm64/${NAME}.app/Contents/MacOS/${SHORT_NAME}" "fyne-cross/dist/darwin-amd64/${NAME}.app/Contents/MacOS/${SHORT_NAME}"
	@echo [✓] Completed

	@echo [i] Finalizing Package
	@cp -R appliances "fyne-cross/dist/darwin-arm64/${NAME}.app/Contents/Resources/"
	@cp -R appliances "fyne-cross/dist/darwin-amd64/${NAME}.app/Contents/Resources/"
	@cp -R appliances "fyne-cross/dist/darwin-universal/${NAME}.app/Contents/Resources/"

	@cp -R appliances.json "fyne-cross/dist/darwin-arm64/${NAME}.app/Contents/Resources/"
	@cp -R appliances.json "fyne-cross/dist/darwin-amd64/${NAME}.app/Contents/Resources/"
	@cp -R appliances.json "fyne-cross/dist/darwin-universal/${NAME}.app/Contents/Resources/"

	@cp -R upgrade/upgrade.sh "fyne-cross/dist/darwin-arm64/${NAME}.app/Contents/Resources/"
	@cp -R upgrade/upgrade.sh "fyne-cross/dist/darwin-amd64/${NAME}.app/Contents/Resources/"
	@cp -R upgrade/upgrade.sh "fyne-cross/dist/darwin-universal/${NAME}.app/Contents/Resources/"

	@mkdir -p "fyne-cross/dist/darwin-arm64/${NAME}.app/Contents/Resources/icons/"
	@mkdir -p "fyne-cross/dist/darwin-amd64/${NAME}.app/Contents/Resources/icons/"
	@mkdir -p "fyne-cross/dist/darwin-universal/${NAME}.app/Contents/Resources/icons/"
	@cp -R Icon.png "fyne-cross/dist/darwin-arm64/${NAME}.app/Contents/Resources/icons/"
	@cp -R Icon.png "fyne-cross/dist/darwin-amd64/${NAME}.app/Contents/Resources/icons/"
	@cp -R Icon.png "fyne-cross/dist/darwin-universal/${NAME}.app/Contents/Resources/icons/"
	@cp -R IconUpgrade.png "fyne-cross/dist/darwin-arm64/${NAME}.app/Contents/Resources/icons/"
	@cp -R IconUpgrade.png "fyne-cross/dist/darwin-amd64/${NAME}.app/Contents/Resources/icons/"
	@cp -R IconUpgrade.png "fyne-cross/dist/darwin-universal/${NAME}.app/Contents/Resources/icons/"

	@cp -R ipv6rs.png "fyne-cross/dist/darwin-arm64/${NAME}.app/Contents/Resources/"
	@cp -R ipv6rs.png "fyne-cross/dist/darwin-amd64/${NAME}.app/Contents/Resources/"
	@cp -R ipv6rs.png "fyne-cross/dist/darwin-universal/${NAME}.app/Contents/Resources/"

	@cd backup && make darwin && cd ..
	@cp -R backup/dist/macos/backup-arm64 "fyne-cross/dist/darwin-arm64/${NAME}.app/Contents/Resources/backup"
	@cp -R backup/dist/macos/backup-amd64 "fyne-cross/dist/darwin-amd64/${NAME}.app/Contents/Resources/backup"
	@lipo -create -output "fyne-cross/dist/darwin-universal/${NAME}.app/Contents/Resources/backup" "backup/dist/macos/backup-arm64" "backup/dist/macos/backup-amd64"

	@cd checker && make darwin && cd ..
	@cp -R checker/dist/macos/checker-arm64 "fyne-cross/dist/darwin-arm64/${NAME}.app/Contents/Resources/checker"
	@cp -R checker/dist/macos/checker-amd64 "fyne-cross/dist/darwin-amd64/${NAME}.app/Contents/Resources/checker"
	@lipo -create -output "fyne-cross/dist/darwin-universal/${NAME}.app/Contents/Resources/checker" "checker/dist/macos/checker-arm64" "checker/dist/macos/checker-amd64"

	@cd tray && make darwin && cd ..
	@cp tray/dist/cloudseeder-monitor-macos-arm64 "fyne-cross/dist/darwin-arm64/${NAME}.app/Contents/MacOS/cloudseeder-monitor"
	@cp tray/dist/cloudseeder-monitor-macos-amd64 "fyne-cross/dist/darwin-amd64/${NAME}.app/Contents/MacOS/cloudseeder-monitor"
	@lipo -create -output "fyne-cross/dist/darwin-universal/${NAME}.app/Contents/MacOS/cloudseeder-monitor" "tray/dist/cloudseeder-monitor-macos-arm64" "tray/dist/cloudseeder-monitor-macos-amd64"

	@mkdir -p dist/
	@mv "fyne-cross/dist/darwin-arm64/${NAME}.app" "dist/${NAME}-mac-arm64.app"
	@mv "fyne-cross/dist/darwin-amd64/${NAME}.app" "dist/${NAME}-mac-amd64.app"
	@mv "fyne-cross/dist/darwin-universal/${NAME}.app" "dist/${NAME}-mac-universal.app"

	@rm -rf fyne-cross/
	@echo [✓] Completed

linux-x86:
	@rm -rf fyne-cross/dist/linux-amd64
	@fyne-cross linux -arch=amd64 -app-id=${APP_ID} src/

	@echo [i] Preparing Linux .tar.gz Packages
	@tar -xf fyne-cross/dist/linux-amd64/${CURRENT_FOLDER}.tar.xz -C fyne-cross/dist/linux-amd64/

	@mkdir -p fyne-cross/dist/linux-amd64/bin
	@mkdir -p fyne-cross/dist/linux-amd64/Resources

	@cp -R fyne-cross/dist/linux-amd64/usr/local/bin/${SHORT_NAME} fyne-cross/dist/linux-amd64/bin

	@echo [i] Finalizing Packages Appliance Data
	@cp -R appliances fyne-cross/dist/linux-amd64/Resources/
	@cp -R appliances.json fyne-cross/dist/linux-amd64/Resources/
	@cp -R upgrade/upgrade.sh fyne-cross/dist/linux-amd64/Resources/
	@mkdir -p fyne-cross/dist/linux-amd64/Resources/icons/
	@cp -R Icon.png fyne-cross/dist/linux-amd64/Resources/icons/
	@cp -R IconUpgrade.png fyne-cross/dist/linux-amd64/Resources/icons/
	@cp -R ipv6rs.png fyne-cross/dist/linux-amd64/Resources/
	@cp -R util/linux_init.sh fyne-cross/dist/linux-amd64/Resources/

	@cd backup && make linux-x86 && cd ..
	@cp -R backup/dist/linux/backup-amd64 "fyne-cross/dist/linux-amd64/Resources/backup"

	@cd checker && make linux-x86 && cd ..
	@cp -R checker/dist/linux/checker-amd64 "fyne-cross/dist/linux-amd64/Resources/checker"

	@cd tray && make linux-x86 && cd ..
	@cp tray/dist/cloudseeder-monitor-linux-amd64 "fyne-cross/dist/linux-amd64/bin/cloudseeder-monitor"

	@rm fyne-cross/dist/linux-amd64/Makefile

	@rm fyne-cross/dist/linux-amd64/${CURRENT_FOLDER}.tar.xz

	@rm -rf fyne-cross/dist/linux-amd64/${CURRENT_FOLDER}

	@rm -rf fyne-cross/dist/linux-amd64/usr

	@mv fyne-cross/dist/linux-amd64 "fyne-cross/dist/${NAME}-linux-amd64"



	@mkdir -p dist/
	@tar -czf "dist/${NAME}-linux-amd64.tgz" -C "fyne-cross/dist/" "${NAME}-linux-amd64"

	@rm -rf fyne-cross/
	@echo [✓] Completed all tasks.

linux-arm:
	@rm -rf fyne-cross/dist/linux-arm64
	@fyne-cross linux -arch=arm64 -app-id=${APP_ID} src/

	@echo [i] Preparing Linux .tar.gz Packages
	@tar -xf fyne-cross/dist/linux-arm64/${CURRENT_FOLDER}.tar.xz -C fyne-cross/dist/linux-arm64/

	@mkdir -p fyne-cross/dist/linux-arm64/bin
	@mkdir -p fyne-cross/dist/linux-arm64/Resources

	@cp -R fyne-cross/dist/linux-arm64/usr/local/bin/${SHORT_NAME} fyne-cross/dist/linux-arm64/bin

	@echo [i] Finalizing Packages Appliance Data
	@cp -R appliances fyne-cross/dist/linux-arm64/Resources/
	@cp -R appliances.json fyne-cross/dist/linux-arm64/Resources/
	@cp -R upgrade/upgrade.sh fyne-cross/dist/linux-arm64/Resources/
	@mkdir -p fyne-cross/dist/linux-arm64/Resources/icons/
	@cp -R Icon.png fyne-cross/dist/linux-arm64/Resources/icons/
	@cp -R IconUpgrade.png fyne-cross/dist/linux-arm64/Resources/icons/
	@cp -R ipv6rs.png fyne-cross/dist/linux-arm64/Resources/
	@cp -R util/linux_init.sh fyne-cross/dist/linux-arm64/Resources/

	@cd backup && make linux-arm && cd ..
	@cp -R backup/dist/linux/backup-arm64 "fyne-cross/dist/linux-arm64/Resources/backup"

	@cd checker && make linux-arm && cd ..
	@cp -R checker/dist/linux/checker-arm64 "fyne-cross/dist/linux-arm64/Resources/checker"

	@cd tray && make linux-arm && cd ..
	@cp tray/dist/cloudseeder-monitor-linux-arm64 "fyne-cross/dist/linux-arm64/bin/cloudseeder-monitor"

	@rm fyne-cross/dist/linux-arm64/Makefile

	@rm fyne-cross/dist/linux-arm64/${CURRENT_FOLDER}.tar.xz

	@rm -rf fyne-cross/dist/linux-arm64/${CURRENT_FOLDER}

	@rm -rf fyne-cross/dist/linux-arm64/usr

	@mv fyne-cross/dist/linux-arm64 "fyne-cross/dist/${NAME}-linux-arm64"

	@mkdir -p dist/
	@tar -czf "dist/${NAME}-linux-arm64.tgz" -C "fyne-cross/dist/" "${NAME}-linux-arm64"

	@rm -rf fyne-cross/
	@echo [✓] Completed all tasks.

windows-x86:
	@rm -rf fyne-cross/dist/windows-amd64
	@rm -rf "fyne-cross/dist/${NAME}-windows-amd64"

	@fyne-cross windows -arch=amd64 -app-id=${APP_ID} src/

	@unzip fyne-cross/dist/windows-amd64/${CURRENT_FOLDER}.exe.zip -d fyne-cross/dist/windows-amd64/ > /dev/null 2>&1

	@echo [i] Preparing Windows Zip Packages
	@mkdir -p fyne-cross/dist/windows-amd64/bin/
	@mkdir -p fyne-cross/dist/windows-amd64/Resources/

	@mv fyne-cross/dist/windows-amd64/${CURRENT_FOLDER}.exe fyne-cross/dist/windows-amd64/bin/${SHORT_NAME}.exe

	@echo [i] Finalizing Packages Appliance Data
	@cp -R appliances fyne-cross/dist/windows-amd64/Resources/
	@cp -R appliances.json fyne-cross/dist/windows-amd64/Resources/
	@cp -R upgrade/upgrade.ps1 fyne-cross/dist/windows-amd64/Resources/
	@mkdir -p fyne-cross/dist/windows-amd64/Resources/icons/
	@cp -R Icon.png fyne-cross/dist/windows-amd64/Resources/icons/
	@cp -R IconUpgrade.png fyne-cross/dist/windows-amd64/Resources/icons/
	@cp -R ipv6rs.png fyne-cross/dist/windows-amd64/Resources/

	@cd backup && make windows-x86 && cd ..
	@cp -R backup/dist/windows/backup-amd64.exe "fyne-cross/dist/windows-amd64/Resources/backup.exe"

	@cd checker && make windows-x86 && cd ..
	@cp -R checker/dist/windows/checker-amd64.exe "fyne-cross/dist/windows-amd64/Resources/checker.exe"

	@cd tray && make windows-x86 && cd ..
	@cp tray/dist/cloudseeder-monitor-windows-amd64.exe "fyne-cross/dist/windows-amd64/bin/cloudseeder-monitor.exe"

	@rm fyne-cross/dist/windows-amd64/${CURRENT_FOLDER}.exe.zip

	@(cd fyne-cross/dist/ && mv windows-amd64 "${NAME}-windows-amd64" && zip -r "${NAME}-windows-amd64.zip" "./${NAME}-windows-amd64" > /dev/null 2>&1)
	@mv "fyne-cross/dist/${NAME}-windows-amd64.zip" "dist/${NAME}-windows-amd64.zip"

	@rm -rf fyne-cross/
	@echo [✓] Completed all tasks.

windows-arm:
	@rm -rf fyne-cross/dist/windows-arm64
	@rm -rf "fyne-cross/dist/${NAME}-windows-arm64"

	@fyne-cross windows -arch=arm64 -app-id=${APP_ID} src/

	@unzip fyne-cross/dist/windows-arm64/${CURRENT_FOLDER}.exe.zip -d fyne-cross/dist/windows-arm64/ > /dev/null 2>&1

	@echo [i] Preparing Windows Zip Packages
	@mkdir -p fyne-cross/dist/windows-arm64/bin/
	@mkdir -p fyne-cross/dist/windows-arm64/Resources/

	@mv fyne-cross/dist/windows-arm64/${CURRENT_FOLDER}.exe fyne-cross/dist/windows-arm64/bin/${SHORT_NAME}.exe

	@echo [i] Finalizing Packages Appliance Data
	@cp -R appliances fyne-cross/dist/windows-arm64/Resources/
	@cp -R appliances.json fyne-cross/dist/windows-arm64/Resources/
	@cp -R upgrade/upgrade.ps1 fyne-cross/dist/windows-arm64/Resources/
	@mkdir -p fyne-cross/dist/windows-arm64/Resources/icons/
	@cp -R Icon.png fyne-cross/dist/windows-arm64/Resources/icons/
	@cp -R IconUpgrade.png fyne-cross/dist/windows-arm64/Resources/icons/
	@cp -R ipv6rs.png fyne-cross/dist/windows-arm64/Resources/

	@cd backup && make windows-arm && cd ..
	@cp -R backup/dist/windows/backup-arm64.exe "fyne-cross/dist/windows-arm64/Resources/backup.exe"

	@cd checker && make windows-arm && cd ..
	@cp -R checker/dist/windows/checker-arm64.exe "fyne-cross/dist/windows-arm64/Resources/checker.exe"

	@cd tray && make windows-arm && cd ..
	@cp tray/dist/cloudseeder-monitor-windows-arm64.exe "fyne-cross/dist/windows-arm64/bin/cloudseeder-monitor.exe"

	@rm fyne-cross/dist/windows-arm64/${CURRENT_FOLDER}.exe.zip

	@(cd fyne-cross/dist/ && mv windows-arm64 "${NAME}-windows-arm64" && zip -r "${NAME}-windows-arm64.zip" "./${NAME}-windows-arm64" > /dev/null 2>&1)
	@mv "fyne-cross/dist/${NAME}-windows-arm64.zip" "dist/${NAME}-windows-arm64.zip"

	@rm -rf fyne-cross/
	@echo [✓] Completed all tasks.

clean-build:
	rm -rf fyne-cross

clean:
	rm -rf dist/*
	cd backup && make clean && cd ..
	cd checker && make clean && cd ..
	cd tray && make clean && cd ..

help:
	@echo "Available commands:"
	@echo "  all          - Builds everything"
	@echo "  darwin       - Builds macOS x86, ARM and Universal"
	@echo "  linux        - Builds Linux x86 and ARM"
	@echo "  windows-x86  - Builds Windows x86"
	@echo "  windows-arm  - Builds Windows ARM"
	@echo "  clean        - Deletes the binaries"
	@echo "  help         - Displays this help"

