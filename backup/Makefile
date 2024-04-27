##
##
## Makefile
## Provides a Makefile for Cloud Seeder backup by IPv6rs
##
## Distributed under the COOLER License.
##
## Copyright (c) 2024 IPv6.rs <https://ipv6.rs>
## All Rights Reserved
##
##
.PHONY: all build-darwin build-windows build-linux clean
OUTPUT_DIR := ./dist
GO := go
GOBUILD := $(GO) build -v
$(shell mkdir -p $(OUTPUT_DIR))

all: darwin windows-x86 windows-arm linux-x86 linux-arm

darwin:
	mkdir -p $(OUTPUT_DIR)/macos/
	GOOS=darwin GOARCH=amd64 $(GOBUILD) -o $(OUTPUT_DIR)/macos/backup-amd64 .
	GOOS=darwin GOARCH=arm64 $(GOBUILD) -o $(OUTPUT_DIR)/macos/backup-arm64 .

windows-x86:
	mkdir -p $(OUTPUT_DIR)/windows/
	GOOS=windows GOARCH=amd64 $(GOBUILD) -o $(OUTPUT_DIR)/windows/backup-amd64.exe .

windows-arm:
	mkdir -p $(OUTPUT_DIR)/windows/
	GOOS=windows GOARCH=arm64 $(GOBUILD) -o $(OUTPUT_DIR)/windows/backup-arm64.exe .

linux-x86:
	mkdir -p $(OUTPUT_DIR)/linux/
	GOOS=linux GOARCH=amd64 $(GOBUILD) -o $(OUTPUT_DIR)/linux/backup-amd64 .

linux-arm:
	mkdir -p $(OUTPUT_DIR)/linux/
	GOOS=linux GOARCH=arm64 $(GOBUILD) -o $(OUTPUT_DIR)/linux/backup-arm64 .

clean:
	rm -rf $(OUTPUT_DIR)
