# xtty-test.pkr.hcl — the minimal xtty test-VM image (~40 GB).
#
# A strip-down of cirruslabs/macos-image-templates' templates/xcode.pkr.hcl:
# pinned macOS base + Xcode (macOS SDK only) + XcodeGen. Deliberately absent
# relative to the cirruslabs xcode image: all simulator/platform downloads
# (iOS/watchOS/tvOS/visionOS), the Android SDK/NDK, Flutter,
# fastlane/cocoapods/rbenv/tuist, libimobiledevice, the codex/claude-code/
# amazon-q casks, the multiple-Xcode install loop, and the Metal-toolchain
# component (xtty builds Metal-free — see the retire-metal-renderer change).
#
# Build with `make image` (checks prerequisites, then packer init + build).
# Docs: packer/README.md. Design: openspec/changes/add-xtty-test-image/design.md.

packer {
  required_plugins {
    tart = {
      version = ">= 1.12.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

# ---- Pinned inputs (record every change in packer/README.md ▸ Maintenance) ----

variable "base_image" {
  type = string
  # macos-tahoe-base publishes only a :latest tag (no version tags), so the
  # reproducibility pin is the manifest DIGEST — stronger than a tag.
  # Resolved 2026-07-04; upload-time annotation 2026-06-06.
  default = "ghcr.io/cirruslabs/macos-tahoe-base@sha256:a8e1c8305758643f513fdccdd829c2243687c60791083dea42f73f0b7aeb435c"
  description = "Pinned cirruslabs base image (carries the XCUITest infra: auto-login, automation mode, TCC grants, NOPASSWD sudo, brew)."
}

variable "xcode_version" {
  type    = string
  default = "26.5" # CI parity: the macos-26 hosted runner's release default + the proven Tart rig.
  description = "Xcode version installed from the pre-downloaded ~/XcodesCache/Xcode_<version>.xip (never downloaded during the build)."
}

variable "disk_size" {
  type    = number
  # A MAX, not the footprint (the built image materializes ~40 GB). 60 (> the
  # base's nominal 50) gives the unxip transient headroom: .xip (~12 GB) +
  # expanding Xcode.app coexist before the cleanup provisioner runs.
  default = 60
}

source "tart-cli" "tart" {
  vm_base_name = var.base_image
  vm_name      = "xtty-test:${var.xcode_version}"
  # Build-time resources only. The race-reproducing 3-vCPU constraint is a
  # RUN-time property of the test clone (tart set <clone> --cpu 3), not baked in.
  cpu_count    = 4
  memory_gb    = 8
  disk_size_gb = var.disk_size
  headless     = true
  ssh_password = "admin"
  ssh_username = "admin"
  ssh_timeout  = "120s"
}

build {
  sources = ["source.tart-cli.tart"]

  # The official Apple installer archive, pre-downloaded ONCE with an Apple ID
  # (xcodes download <version>). The build itself performs zero Apple
  # authentication — this copy is the only way Xcode enters the guest.
  provisioner "file" {
    source      = pathexpand("~/XcodesCache/Xcode_${var.xcode_version}.xip")
    destination = "/Users/admin/Downloads/"
  }

  # xcodes as INSTALLER (not downloader): --path installs from the local .xip.
  # Same idiom as cirruslabs xcode.pkr.hcl (install → resolve path → move to
  # /Applications → select).
  provisioner "shell" {
    inline = [
      "source ~/.zprofile",
      "brew install xcodes",
      "xcodes version",
      "sudo xcodes install ${var.xcode_version} --experimental-unxip --path /Users/admin/Downloads/Xcode_${var.xcode_version}.xip --select --empty-trash",
      "INSTALLED_PATH=$(xcodes select -p)",
      "CONTENTS_DIR=$(dirname $INSTALLED_PATH)",
      "APP_DIR=$(dirname $CONTENTS_DIR)",
      "sudo mv $APP_DIR /Applications/Xcode_${var.xcode_version}.app",
      "sudo xcode-select -s /Applications/Xcode_${var.xcode_version}.app",
      "sudo xcodebuild -license accept",
    ]
  }

  # First-launch package installs — and NOTHING more:
  #  - no -downloadPlatform / -downloadAllPlatforms (that single omission is the
  #    ~45 GB of simulators — the whole 87→40 GB win)
  #  - no -downloadComponent MetalToolchain (a deterministic Apple-catalog-
  #    rotation trap at arbitrary build times; unnecessary post-retire-metal-renderer)
  provisioner "shell" {
    inline = [
      "source ~/.zprofile",
      "xcodebuild -runFirstLaunch",
    ]
  }

  # xtty's project generator (the only project-specific tool; the xtty source
  # itself is deliberately NOT baked in — it arrives at test time in a clone).
  provisioner "shell" {
    inline = [
      "source ~/.zprofile",
      "brew install xcodegen",
      "xcodegen --version",
    ]
  }

  # macOS 15+/26 Local Network privacy note (NO working pre-suppression baked —
  # see below). On macOS 26.5 (which macos-tahoe-base:latest now ships, but the
  # frozen macos-tahoe-xcode image does not) the XCUITest runner<->app IPC touches
  # the guest's ROUTABLE vmnet address (not loopback), tripping the per-app Local
  # Network gate → a modal "Allow '<app>' to find devices on local networks?"
  # attributed to the app under test. It is NOT a TCC.db permission and NOT any
  # real networking by the app — purely the XCTest IPC. Impact is BENIGN for the
  # rig's purpose: a HEADLESS run is unaffected (33/8/1 with or without the modal —
  # no window server, no focus theft); only a GRAPHICS run loses ~1 extra Cmd-key
  # test to focus theft. TN3179's AllowedEthernet/WiFiLocalNetworkAddresses defaults
  # were tried (sudo write to com.apple.network.local-network + reboot) and
  # SCREENSHOT-REFUTED — the dialog still appeared, matching the finding that macOS
  # offers no supported offline pre-grant for Local Network. So: run HEADLESS for
  # clean measurement; for graphics watching, click "Allow" once or add an in-test
  # addUIInterruptionMonitor. See research/03-analysis/local-macos-vm-ci-reproduction.md §12.

  # Footprint: drop the installer + caches before the image is sealed.
  provisioner "shell" {
    inline = [
      "source ~/.zprofile",
      "rm -f /Users/admin/Downloads/Xcode_${var.xcode_version}.xip",
      "sudo rm -rf /Users/admin/.Trash/* || true",
      "brew cleanup --prune=all || true",
      "df -h",
    ]
  }
}
