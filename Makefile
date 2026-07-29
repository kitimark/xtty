# Makefile — the single entry point for setting up, building, testing and
# running xtty. It only wraps the commands documented in AGENTS.md -> Building;
# read that section to understand what each target does under the hood.
#
# `make` with no target prints the list below. Two setup steps are modeled as
# real file-targets, so `make build` re-bootstraps SwiftTerm only when the
# pin/patch changed and regenerates the Xcode project only when project.yml
# changed. Prerequisites it can't safely install (XcodeGen, full Xcode) are
# checked by `make doctor`, which advises rather than running sudo. Targeting
# macOS-default GNU make 3.81; keep recipes POSIX-sh.

.DEFAULT_GOAL := help

SCHEME            := xtty
DERIVED           := build
APP               := $(DERIVED)/Build/Products/Debug/xtty.app
XCODEPROJ         := xtty.xcodeproj/project.pbxproj
# The file scripts/bootstrap-swiftterm.sh's patch creates — its presence means
# the gitignored SwiftTerm checkout has been reconstituted and patched.
SWIFTTERM_SENTINEL := external/SwiftTerm/Sources/SwiftTerm/XttyAccessors.swift
SWIFTTERM_INPUTS   := patches/swiftterm/xtty-accessors.diff patches/swiftterm/UPSTREAM_CONFIG.sh

BENCH_DIR         := $(DERIVED)/bench
BENCH_BIN         := $(APP)/Contents/MacOS/xtty

# Optional stable code-signing identity for local builds (see
# scripts/create-signing-cert.sh). When XTTY_SIGN_IDENTITY is set in the
# environment, builds sign with it so TCC grants (e.g. Screen Recording for the
# latency probe) persist across rebuilds instead of re-prompting; unset = the
# default ad-hoc "Sign to Run Locally" (portable, what CI/other devs use).
SIGN_FLAGS :=
ifdef XTTY_SIGN_IDENTITY
SIGN_FLAGS := CODE_SIGN_IDENTITY="$(XTTY_SIGN_IDENTITY)" CODE_SIGN_STYLE=Manual CODE_SIGNING_ALLOWED=YES
endif

# --- make install: stable, versioned, optimized Release build (D1-D5) ---------
# `make install` builds the optimized Release config and copies a self-contained
# bundle into INSTALL_DIR (a copy, so it survives `make clean`; override without
# editing tracked files, e.g. `make install INSTALL_DIR=~/Applications`).
INSTALL_DIR    ?= /Applications
RELEASE_CONFIG := Release
RELEASE_APP    := $(DERIVED)/Build/Products/$(RELEASE_CONFIG)/xtty.app

# Version stamp for the install build (D5). VERSION (the human-facing short
# version) is the latest reachable tag with the leading `v` stripped, falling
# back to project.yml's committed MARKETING_VERSION when no tag is reachable or
# git is unavailable. BUILD (the monotonic build number) is the commit count,
# falling back to 1. Both degrade cleanly in a tagless/no-git tree.
PROJECT_VERSION := $(shell sed -n 's/.*MARKETING_VERSION: *"\([^"]*\)".*/\1/p' project.yml | head -1)
VERSION         := $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
VERSION         := $(or $(VERSION),$(PROJECT_VERSION),0.0.1)
BUILD           := $(shell git rev-list --count HEAD 2>/dev/null || echo 1)

.PHONY: help doctor setup build run install restart test test-core build-core bench audit-leaks design-link design-status design-unlink image image-zsh bootstrap generate clean reset

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

doctor: ## Check prerequisites it can't auto-install (advises; never runs sudo)
	@ok=1; \
	if command -v xcodegen >/dev/null 2>&1; then \
		echo "  ok  xcodegen ($$(xcodegen --version 2>/dev/null | head -1))"; \
	else echo "  --  xcodegen missing            -> brew install xcodegen"; ok=0; fi; \
	dev="$$(xcode-select -p 2>/dev/null)"; \
	if echo "$$dev" | grep -q "Xcode.app"; then echo "  ok  full Xcode ($$dev)"; \
	else echo "  --  full Xcode not selected ($$dev) -> install Xcode, then sudo xcode-select -s /Applications/Xcode.app"; ok=0; fi; \
	if [ "$$ok" = 1 ]; then echo "All prerequisites satisfied."; \
	else echo "Some prerequisites are missing (see above)."; exit 1; fi

setup: doctor $(SWIFTTERM_SENTINEL) $(XCODEPROJ) ## First-time setup: check prereqs, bootstrap SwiftTerm, generate the project
	@echo "Setup complete. Run 'make build' or 'make run'."

# --- file-targets: re-run a setup step only when its tracked inputs change ----

$(SWIFTTERM_SENTINEL): $(SWIFTTERM_INPUTS)
	@scripts/bootstrap-swiftterm.sh

$(XCODEPROJ): project.yml
	@xcodegen generate

# --- build / run / test ------------------------------------------------------

build: $(SWIFTTERM_SENTINEL) $(XCODEPROJ) ## Build the app (auto-bootstraps + generates if stale)
	@xcodebuild -project xtty.xcodeproj -scheme $(SCHEME) -derivedDataPath $(DERIVED) build $(SIGN_FLAGS)

run: build ## Build then launch the app
	@open $(APP)

install: | $(SWIFTTERM_SENTINEL) $(XCODEPROJ) ## Install an optimized, version-stamped Release build into INSTALL_DIR (default /Applications)
	@echo "Building Release (version $(VERSION), build $(BUILD))…"
	@xcodebuild -project xtty.xcodeproj -scheme $(SCHEME) -configuration $(RELEASE_CONFIG) -derivedDataPath $(DERIVED) build $(SIGN_FLAGS) MARKETING_VERSION="$(VERSION)" CURRENT_PROJECT_VERSION="$(BUILD)"
	@if [ -d "$(INSTALL_DIR)/xtty.app" ]; then \
		echo "Backing up existing install -> $(INSTALL_DIR)/xtty.app.bak"; \
		rm -rf "$(INSTALL_DIR)/xtty.app.bak"; \
		mv "$(INSTALL_DIR)/xtty.app" "$(INSTALL_DIR)/xtty.app.bak"; \
	fi
	@ditto "$(RELEASE_APP)" "$(INSTALL_DIR)/xtty.app"
	@echo "Installed xtty $(VERSION) ($(BUILD)) -> $(INSTALL_DIR)/xtty.app"

restart: ## Quit any running xtty and relaunch the installed app
	@pkill -x xtty 2>/dev/null || true
	@open "$(INSTALL_DIR)/xtty.app"

test: $(SWIFTTERM_SENTINEL) $(XCODEPROJ) ## Run the app UI tests (XCUITests)
	@xcodebuild test -project xtty.xcodeproj -scheme $(SCHEME) -destination 'platform=macOS' -derivedDataPath $(DERIVED) $(SIGN_FLAGS)

test-core: $(SWIFTTERM_SENTINEL) ## Run the fast XttyCore unit tests (no app build)
	@swift test --package-path XttyCore

bench: build ## Measure latency+memory (P7a regression baseline); writes a JSON report
	@mkdir -p $(BENCH_DIR)
	@echo "Running benchmark…"
	@"$(BENCH_BIN)" -Benchmark -BenchmarkReport "$(BENCH_DIR)/coregraphics.json" || true
	@echo "Report written to:"; echo "  $(BENCH_DIR)/coregraphics.json"
	@echo "Note: latency needs the Screen Recording grant (System Settings ▸ Privacy & Security) + a visible display;"
	@echo "      without it the report still records memory + renderer, with latency marked unavailable/untrustworthy."
	@echo "Latency (P7b): an SCStream per-frame-displayTime probe, gated by a startup timebase calibration; resolution"
	@echo "      is frame-quantized (~one refresh interval). Pin the display refresh for the steadiest cadence."
	@echo "      Renderer verdict (2026-06-29, gate closed): CoreGraphics — see research/03-analysis/p7-measurement-methodology.md."

build-core: $(SWIFTTERM_SENTINEL) ## Build XttyCore only
	@swift build --package-path XttyCore

audit-leaks: build ## P7c leak/allocation DIAGNOSTIC (leaks+vmmap; NOT a gate — the census churn test is)
	@scripts/audit-leaks.sh

# --- Open Design linkage (research/03-analysis/open-design-integration-forensics.md) ---

design-link: ## Register design/xtty + create/configure the mockups project in the running Open Design app (idempotent)
	@scripts/design-link.sh

design-status: ## Report Open Design linkage (read-only; 0=linked+published, 2=app not running, 1=not linked)
	-@scripts/design-link.sh --status

design-unlink: ## Undo design-link: delete the mockups project + workspace copy, unlink the symlink by hand (idempotent)
	@scripts/design-link.sh --uninstall

# --- local VM test image (packer/README.md) -----------------------------------

# The Xcode pin for the test-VM image; must match a pre-downloaded
# ~/XcodesCache/Xcode_$(IMAGE_XCODE).xip (the one-time Apple-ID step).
IMAGE_XCODE := 26.5
IMAGE_XIP   := $(HOME)/XcodesCache/Xcode_$(IMAGE_XCODE).xip

# Guest login shell for the image: bash (default; tag xtty-test, CI-parity) or
# zsh (tag xtty-test-zsh, exercises xtty's zsh-only shell integration for real).
# NB: the var is IMAGE_SHELL, not SHELL — SHELL is a make built-in (the recipe
# shell); overriding it would break every recipe. Use `make image-zsh` or
# `make image IMAGE_SHELL=zsh`.
IMAGE_SHELL := bash

image: ## Build the minimal ~40 GB test-VM image (Packer+Tart; prereqs advised, never installed). IMAGE_SHELL=bash|zsh
	@ok=1; \
	if command -v packer >/dev/null 2>&1; then echo "  ok  packer ($$(packer --version 2>/dev/null | head -1))"; \
	else echo "  --  packer missing              -> brew tap hashicorp/tap && brew install hashicorp/tap/packer"; ok=0; fi; \
	if command -v tart >/dev/null 2>&1; then echo "  ok  tart ($$(tart --version 2>/dev/null))"; \
	else echo "  --  tart missing                -> brew install cirruslabs/cli/tart"; ok=0; fi; \
	if [ -f "$(IMAGE_XIP)" ]; then echo "  ok  Xcode installer ($(IMAGE_XIP))"; \
	else echo "  --  Xcode installer missing     -> xcodes download $(IMAGE_XCODE) --directory ~/XcodesCache   (Apple ID, once)"; ok=0; fi; \
	if [ "$$ok" = 1 ]; then echo "Building into TART_HOME=$${TART_HOME:-~/.tart} (set TART_HOME to pick the volume — see packer/README.md)"; \
	else echo "Missing image prerequisites (see above; packer/README.md)."; exit 1; fi
	@cd packer && packer init xtty-test.pkr.hcl && packer build -var "xcode_version=$(IMAGE_XCODE)" -var "shell=$(IMAGE_SHELL)" xtty-test.pkr.hcl

image-zsh: ## Build the zsh-login-shell variant (xtty-test-zsh) — exercises xtty's real shell integration
	@$(MAKE) image IMAGE_SHELL=zsh

# --- force / housekeeping -----------------------------------------------------

bootstrap: ## Force re-run the SwiftTerm bootstrap (after editing the pin/patch)
	@scripts/bootstrap-swiftterm.sh

generate: ## Force regenerate the Xcode project (after editing project.yml)
	@xcodegen generate

clean: ## Remove build outputs (DerivedData + SPM .build dirs)
	@rm -rf $(DERIVED) XttyCore/.build .build

reset: ## Nuke the SwiftTerm checkout, re-bootstrap and regenerate from scratch
	@rm -rf external/SwiftTerm
	@scripts/bootstrap-swiftterm.sh
	@xcodegen generate
