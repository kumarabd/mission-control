# Mission Control — one entry point for every client.

JAVA_HOME ?= /Applications/Android Studio.app/Contents/jbr/Contents/Home

.PHONY: help web-dev web-check android-check apple-check ios-build macos-build foundations tokens fonts check

help:
	@echo "web-dev       Start the web console (http://localhost:5173)"
	@echo "web-check     Lint, typecheck, test and build the web console"
	@echo "android-check Unit tests and debug build for Android"
	@echo "apple-check   Swift package build and tests for macOS"
	@echo "ios-build     Build the iOS app for the simulator (unsigned)"
	@echo "macos-build   Build the macOS app (unsigned)"
	@echo "tokens        Regenerate design tokens for web, Swift and Kotlin"
	@echo "fonts         Sync the canonical fonts into the native bundles"
	@echo "foundations   Check generated tokens and font copies for drift"
	@echo "check         foundations + web-check + android-check + apple-check"

tokens:
	node scripts/tokens.mjs

fonts:
	./scripts/sync-fonts.sh

foundations:
	node scripts/tokens.mjs --check
	./scripts/sync-fonts.sh --check

web-dev:
	npm run dev

web-check:
	npm run lint
	npm run typecheck
	npm test
	npm run build

android-check:
	cd apps/android && JAVA_HOME="$(JAVA_HOME)" ./gradlew :app:testDebugUnitTest :app:assembleDebug

apple-check:
	cd apps/macos && swift build && swift test

ios-build:
	xcodebuild -project apps/ios/MissionControl.xcodeproj -scheme MissionControl \
		-destination 'generic/platform=iOS Simulator' \
		-skipMacroValidation build CODE_SIGNING_ALLOWED=NO

macos-build:
	cd apps/macos && xcodebuild -project MissionControl.xcodeproj -scheme MissionControl \
		-destination 'platform=macOS' -skipMacroValidation build CODE_SIGNING_ALLOWED=NO

check: foundations web-check apple-check android-check
