.PHONY: help build build-debug build-release package package-debug package-release \
	run open dmg test bootstrap icons clean xcodebuild-args

CONFIG ?= debug
PROJECT := CursorBar.xcodeproj
SCHEME := CursorBar
APP := CursorBar.app
DERIVED_DATA := $(CURDIR)/.derivedData
SCRIPTS := scripts

# Override for signed builds: make build CODE_SIGN_IDENTITY="Apple Development"
CODE_SIGN_IDENTITY ?= -
CODE_SIGNING_ALLOWED ?= NO

XCODEBUILD := xcodebuild \
	-project $(PROJECT) \
	-scheme $(SCHEME) \
	-derivedDataPath $(DERIVED_DATA) \
	CODE_SIGN_IDENTITY="$(CODE_SIGN_IDENTITY)" \
	CODE_SIGNING_ALLOWED=$(CODE_SIGNING_ALLOWED)

help:
	@echo "CursorBar — make targets"
	@echo ""
	@echo "  make build            Build debug app (default)"
	@echo "  make build-release    Build release app"
	@echo "  make package          Copy $(APP) to project root (debug)"
	@echo "  make package-release  Copy $(APP) to project root (release)"
	@echo "  make run              Build, package, and open $(APP)"
	@echo "  make open             Open $(PROJECT) in Xcode"
	@echo "  make dmg              Build release app and create dist/*.dmg"
	@echo "  make test             Build and run unit/UI tests"
	@echo "  make bootstrap        Seed ~/.cursorbar/config.toml"
	@echo "  make icons            Regenerate app/menu bar icons"
	@echo "  make clean            Remove build artifacts and $(APP)"
	@echo ""
	@echo "Variables:"
	@echo "  CONFIG=debug|release  Used by run (default: debug)"
	@echo "  CODE_SIGN_IDENTITY    Set to your cert for signed builds"

build build-debug:
	$(XCODEBUILD) -configuration Debug build

build-release:
	$(XCODEBUILD) -configuration Release build

package package-debug: build-debug
	bash $(SCRIPTS)/package-app.sh debug

package-release: build-release
	bash $(SCRIPTS)/package-app.sh release

run:
	bash $(SCRIPTS)/run-app.sh $(CONFIG)

open:
	open $(PROJECT)

dmg:
	bash $(SCRIPTS)/create-dmg.sh

test:
	bash $(SCRIPTS)/test.sh

bootstrap:
	bash $(SCRIPTS)/bootstrap-config.sh

icons:
	bash $(SCRIPTS)/generate-icons.sh

clean:
	rm -rf $(DERIVED_DATA) "$(APP)" dist
