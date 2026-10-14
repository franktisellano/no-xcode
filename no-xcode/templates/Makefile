# __APP__: everything from the terminal, no Xcode GUI.
#
#   make run          boot simulator, build, install, launch in test mode
#   make screenshot   capture the simulator to build/screenshot.png
#   make test         unit tests          make tour   screenshot tour → build/screenshots/
#   make device-run   build + install + launch on a paired iPhone
#   make testflight   archive + upload to TestFlight (needs .asc.env)
#
# Overrides: SIM="iPhone 16"  OS=26.0  APPEARANCE=dark  DEVICE_NAME="My iPhone"

APP       := __APP__
PROJECT   := $(APP).xcodeproj
SCHEME    := $(APP)
BUNDLE_ID := __BUNDLE_ID__
DERIVED   := build
XCB       := tools/xcb.sh

SIM        ?= iPhone 17 Pro
OS         ?=
APPEARANCE ?= light
DEVICE_NAME ?=
# Env var the app reads to enter its DEBUG-only test mode (see $(APP)/TestMode.swift).
TEST_ENV   := APP_TEST_MODE=1

# Resolved lazily and only once per make invocation (the eval caches the result).
UDID        = $(eval UDID := $(shell tools/sim-udid.sh "$(SIM)" "$(OS)"))$(UDID)
DEVICE_UDID = $(eval DEVICE_UDID := $(shell tools/device-udid.sh "$(DEVICE_NAME)"))$(DEVICE_UDID)

SIM_APP    := $(DERIVED)/Build/Products/Debug-iphonesimulator/$(APP).app
DEVICE_APP := $(DERIVED)/Build/Products/Debug-iphoneos/$(APP).app
DEST        = platform=iOS Simulator,id=$(UDID)
SHOT       ?= $(DERIVED)/screenshot.png
RESULT     ?= $(DERIVED)/ui.xcresult
SHOTSDIR   ?= $(DERIVED)/screenshots

# App Store Connect API key (optional for device builds, required for testflight).
-include .asc.env
ifdef ASC_KEY_ID
ASC_AUTH := -authenticationKeyID $(ASC_KEY_ID) -authenticationKeyIssuerID $(ASC_ISSUER_ID) \
            -authenticationKeyPath $(subst ~,$(HOME),$(ASC_KEY_PATH))
endif

.PHONY: gen build test run run-real boot install launch launch-real screenshot ui-test screenshots tour \
        logs-sim sims devices device-build device-install device-run device-logs archive testflight shutdown clean

## Regenerate the Xcode project from project.yml.
gen:
	@xcodegen generate --quiet

## Simulator build (compile check).
build: gen
	@$(XCB) -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-destination '$(DEST)' -derivedDataPath $(DERIVED) build

## Unit tests.
test: gen
	@$(XCB) -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' \
		-derivedDataPath $(DERIVED) -only-testing:$(APP)Tests CODE_SIGNING_ALLOWED=NO test

## Boot the simulator (no-op if booted), set appearance, show the Simulator window.
boot:
	@xcrun simctl boot $(UDID) 2>/dev/null || true
	@xcrun simctl bootstatus $(UDID) -b >/dev/null
	@xcrun simctl ui $(UDID) appearance $(APPEARANCE) 2>/dev/null || true
	@open -a Simulator --args -CurrentDeviceUDID $(UDID)

install:
	@xcrun simctl install $(UDID) "$(SIM_APP)"

## Launch in test mode (seeded data, stubbed services).
launch:
	@SIMCTL_CHILD_$(TEST_ENV) xcrun simctl launch --terminate-running-process $(UDID) $(BUNDLE_ID) >/dev/null
	@echo "Launched $(APP) in test mode on $(SIM) ($(UDID))"

## Launch normally (real data path).
launch-real:
	@xcrun simctl launch --terminate-running-process $(UDID) $(BUNDLE_ID) >/dev/null
	@echo "Launched $(APP) on $(SIM) ($(UDID))"

run: boot build install launch
run-real: boot build install launch-real

## Screenshot the booted simulator. Give the UI a moment to settle after launch.
screenshot:
	@sleep $${SETTLE:-1}
	@xcrun simctl io $(UDID) screenshot "$(SHOT)" >/dev/null 2>&1
	@echo "Wrote $(SHOT)"

## XCUITest suite; results (incl. screenshots) in $(RESULT).
ui-test: gen
	@rm -rf $(RESULT)
	@$(XCB) -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' \
		-derivedDataPath $(DERIVED) -only-testing:$(APP)UITests \
		-resultBundlePath $(RESULT) CODE_SIGNING_ALLOWED=NO test

## UI suite, then export every named screenshot to $(SHOTSDIR).
## Exports even when tests fail (the screenshots help explain why), then keeps the exit code.
screenshots:
	@$(MAKE) --no-print-directory ui-test; s=$$?; tools/export-screenshots.sh $(RESULT) $(SHOTSDIR); exit $$s

## Screenshot tour only (Tour-NN-*.png).
tour: gen
	@rm -rf $(RESULT)
	@$(XCB) -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' \
		-derivedDataPath $(DERIVED) -only-testing:$(APP)UITests/ScreenshotTourTests \
		-resultBundlePath $(RESULT) CODE_SIGNING_ALLOWED=NO test; s=$$?; \
		tools/export-screenshots.sh $(RESULT) $(SHOTSDIR); exit $$s

## Stream the app's unified log from the simulator (Ctrl-C to stop).
logs-sim:
	xcrun simctl spawn $(UDID) log stream --level debug --style compact \
		--predicate 'subsystem == "$(BUNDLE_ID)" OR process == "$(APP)"'

sims:
	@xcrun simctl list devices available | grep -E "iPhone|iPad|-- iOS"

devices:
	@xcrun devicectl list devices

# ---------------------------------------------------------------------------
# Physical device + release (automatic signing, no Xcode GUI)
# ---------------------------------------------------------------------------

## Signed debug build for iOS devices.
device-build: gen
	@$(XCB) -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-destination 'generic/platform=iOS' -derivedDataPath $(DERIVED) \
		-allowProvisioningUpdates -allowProvisioningDeviceRegistration $(ASC_AUTH) build

## Install on the phone (must be unlocked, trusted, Developer Mode on).
device-install: device-build
	@test -n "$(DEVICE_UDID)" || exit 1
	xcrun devicectl device install app --device $(DEVICE_UDID) "$(DEVICE_APP)"

device-run: device-install
	xcrun devicectl device process launch --device $(DEVICE_UDID) $(BUNDLE_ID)

## Launch with the console attached (print/os_log output; Ctrl-C to stop).
device-logs:
	@test -n "$(DEVICE_UDID)" || exit 1
	xcrun devicectl device process launch --device $(DEVICE_UDID) --terminate-existing --console $(BUNDLE_ID)

## Release archive only; prints the signing identity.
archive: gen
	@$(XCB) -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-destination 'generic/platform=iOS' -archivePath $(DERIVED)/$(APP).xcarchive \
		-allowProvisioningUpdates $(ASC_AUTH) archive

## Archive + export + upload to TestFlight. BUILD=<n> pins the build number.
testflight:
	tools/testflight-upload.sh $(BUILD)

shutdown:
	@xcrun simctl shutdown $(UDID) 2>/dev/null || true

clean:
	rm -rf $(DERIVED) $(PROJECT)
