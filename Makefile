# Makefile — the single entry point for setting up, building, testing and
# running xtty. It only wraps the commands documented in AGENTS.md -> Building;
# read that section to understand what each target does under the hood.
#
# `make` with no target prints the list below. Two setup steps are modeled as
# real file-targets, so `make build` re-bootstraps SwiftTerm only when the
# pin/patch changed and regenerates the Xcode project only when project.yml
# changed. Prerequisites it can't safely install (XcodeGen, full Xcode, the
# Metal toolchain) are checked by `make doctor`, which advises rather than
# running sudo. Targeting macOS-default GNU make 3.81; keep recipes POSIX-sh.

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

.PHONY: help doctor setup build run test test-core build-core bench bootstrap generate clean reset

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-11s\033[0m %s\n", $$1, $$2}'

doctor: ## Check prerequisites it can't auto-install (advises; never runs sudo)
	@ok=1; \
	if command -v xcodegen >/dev/null 2>&1; then \
		echo "  ok  xcodegen ($$(xcodegen --version 2>/dev/null | head -1))"; \
	else echo "  --  xcodegen missing            -> brew install xcodegen"; ok=0; fi; \
	dev="$$(xcode-select -p 2>/dev/null)"; \
	if echo "$$dev" | grep -q "Xcode.app"; then echo "  ok  full Xcode ($$dev)"; \
	else echo "  --  full Xcode not selected ($$dev) -> install Xcode, then sudo xcode-select -s /Applications/Xcode.app"; ok=0; fi; \
	if xcrun -f metal >/dev/null 2>&1; then echo "  ok  Metal toolchain"; \
	else echo "  --  Metal toolchain missing     -> sudo xcodebuild -downloadComponent MetalToolchain"; ok=0; fi; \
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

test: $(SWIFTTERM_SENTINEL) $(XCODEPROJ) ## Run the app UI tests (XCUITests)
	@xcodebuild test -project xtty.xcodeproj -scheme $(SCHEME) -destination 'platform=macOS' -derivedDataPath $(DERIVED) $(SIGN_FLAGS)

test-core: $(SWIFTTERM_SENTINEL) ## Run the fast XttyCore unit tests (no app build)
	@swift test --package-path XttyCore

bench: build ## Measure latency+memory for both renderers; writes JSON reports (P7a)
	@mkdir -p $(BENCH_DIR)
	@echo "Running benchmark (CoreGraphics)…"
	@"$(BENCH_BIN)" -Benchmark -UITestRenderer coregraphics -BenchmarkReport "$(BENCH_DIR)/coregraphics.json" || true
	@echo "Running benchmark (Metal)…"
	@"$(BENCH_BIN)" -Benchmark -UITestRenderer metal -BenchmarkReport "$(BENCH_DIR)/metal.json" || true
	@echo "Reports written to:"; echo "  $(BENCH_DIR)/coregraphics.json"; echo "  $(BENCH_DIR)/metal.json"
	@echo "Note: latency needs the Screen Recording grant (System Settings ▸ Privacy & Security) + a visible display;"
	@echo "      without it the report still records memory + renderer, with latency marked unavailable."
	@echo "Caveat: the latency probe is COARSE (each capture ~20ms > the key-to-photon signal) — memory is the"
	@echo "        trustworthy result; a finer latency probe (SCStream timestamps / engine hook) is P7b work."

build-core: $(SWIFTTERM_SENTINEL) ## Build XttyCore only
	@swift build --package-path XttyCore

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
