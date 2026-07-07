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

variable "shell" {
  type    = string
  default = "bash"
  # The guest's auto-login interactive shell. `bash` = the CI-parity,
  # acceptance-bearing rig (byte-identical to today's image, tag xtty-test).
  # `zsh` = the supplement rig that exercises xtty's zsh-only OSC 7/133 shell
  # integration for real (tag xtty-test-zsh) and neutralizes the Local Network
  # gate at the rig level. See openspec/changes/add-zsh-test-image + design.md.
  description = "Guest login shell: bash (CI-parity rig) or zsh (real-shell-integration supplement rig)."
  validation {
    condition     = contains(["bash", "zsh"], var.shell)
    error_message = "The shell variable must be \"bash\" or \"zsh\"."
  }
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
  # bash -> xtty-test:<ver> (unchanged); zsh -> xtty-test-zsh:<ver>. One
  # template, two tags — the only build-time difference is the login shell +
  # (zsh only) the Local Network neutralization daemon.
  vm_name      = "xtty-test${var.shell == "zsh" ? "-zsh" : ""}:${var.xcode_version}"
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

  # Login shell (parameterized — var.shell, default bash). GitHub's hosted
  # macOS runners set the runner account's shell to bash (runner-images
  # configure-shell.sh: chsh -s /bin/bash), so the CI-parity rig runs under
  # bash. That also removes the macOS Local Network privacy modal from graphics
  # runs. Measured root cause (2026-07-05, lldb backtrace + per-config log
  # captures — supersedes the earlier "XCUITest IPC over the routable vmnet
  # address" theory): xtty reads its own host name via ProcessInfo.hostName →
  # NSHost → a reverse-DNS lookup of every local address, and that code path
  # runs only when the shell emits OSC 7 — i.e. under zsh (xtty injects shell
  # integration into zsh only), never bash. Setting a static HostName does NOT
  # help (the reverse lookups still fire, measured 20/launch either way);
  # TN3179's Allowed*LocalNetworkAddresses defaults were separately
  # screenshot-refuted for the guest-side modal (the zsh variant bakes them in
  # and re-tests by effect at owner request — see the zsh block below). Under
  # bash there is no OSC 7, no reverse DNS, and
  # nothing for the Local Network gate to prompt about — the same reason the
  # hosted runners and the frozen macos-tahoe-xcode rig never show the dialog.
  # Semantic-capture tests take their graceful-degradation arms under bash,
  # exactly as on CI.
  #
  # The zsh variant (var.shell=zsh) deliberately re-enables that OSC 7 path so
  # the shell-dependent half of the suite asserts for real, and neutralizes the
  # Local Network gate at the rig level via the daemon installed below (never in
  # xtty product code). See research/03-analysis/local-macos-vm-ci-reproduction.md
  # §12, local-network-privacy-forensics.md, and add-zsh-test-image/design.md.
  provisioner "shell" {
    inline = [
      "sudo chsh -s /bin/${var.shell} admin",
      "sudo chsh -s /bin/${var.shell} root",
      "dscl . -read /Users/admin UserShell",
    ]
  }

  # zsh variant ONLY: apply the Tart FAQ's Local Network permission workaround at
  # the rig level (no xtty product-code change) —
  # https://tart.run/faq/#avoiding-the-local-network-permission-pop-up. The FAQ
  # excludes the RFC-1918 private ranges from the Local Network privacy gate via
  # two `defaults write` to com.apple.network.local-network, and requires a reboot
  # to take effect — which the sealed image gets for free when a test clone boots.
  #
  # OWNER-DIRECTED RE-TEST (2026-07-07): the FAQ is written for the HOST-side
  # Packer→VM pop-up; a prior *runtime* application of these exact keys inside a
  # booted guest was refuted by effect for xtty's guest-side com.xtty.app modal
  # (20 gate events + modal survived, persisted across reboot —
  # local-network-privacy-forensics.md §12d). The mechanism (the gate fires at
  # DNS query-classification, pre-send, keyed on the queried reverse zone — not on
  # the connection destination the FAQ whitelists) predicts the baked-in variant
  # fails identically. This bakes it into the image so it is present before first
  # boot and re-verifies by effect on the graphics rig. bash skips it entirely
  # (no OSC 7 → no prompt), so its sealed image stays byte-identical.
  provisioner "shell" {
    inline = [
      "if [ '${var.shell}' = 'zsh' ]; then",
      "  sudo defaults write com.apple.network.local-network AllowedEthernetLocalNetworkAddresses -array '10.0.0.0/8' '172.16.0.0/12' '192.168.0.0/16'",
      "  sudo defaults write com.apple.network.local-network AllowedWiFiLocalNetworkAddresses -array '10.0.0.0/8' '172.16.0.0/12' '192.168.0.0/16'",
      "  echo 'zsh variant: applied Tart FAQ Local Network address exclusions (com.apple.network.local-network)';",
      "  echo '--- read-back ---'; sudo defaults read com.apple.network.local-network 2>/dev/null || true",
      "else",
      "  echo 'bash variant: no Local Network workaround (no OSC 7, no prompt)';",
      "fi",
    ]
  }

  # CI-parity prompt WIDTH: the hosted runner's live \h is a ~61-char datacenter
  # name (sjc22-be105-…-9E54E01C3448), injected by GitHub's network at runtime —
  # NOT in runner-images' build (which sets only Mac-<epoch>.local). That long \h
  # makes stock /etc/bashrc's PS1='\h:\W \u\$ ' wide enough that a marker typed at
  # the prompt SOFT-WRAPS across physical rows; a short guest hostname
  # (Manageds-Virtual-Machine, 24 chars) does not — which is exactly why the
  # findbar-marker-wrap flake was invisible to this rig and only reds on CI. Give
  # the guest a ~60-char single-label hostname so it reproduces the runner's
  # prompt width and prompt-width-sensitive assertions surface IN-GUEST before CI.
  #
  # Mechanism parity with runner-images/.../configure-hostname.sh: set all THREE
  # keys. Bash \h reads gethostname(3), whose backing key on macOS is not fixed
  # (on bare metal \h tracked LocalHostName+.local while HostName was unset), and
  # which key wins inside a NAT'd Tart guest is unverified — so set all three
  # defensively and VERIFY BY EFFECT (the marker must wrap in the grid dump), not
  # by reading PS1 back. One fixed long name suffices (no per-boot epoch
  # randomization like the runner fleet — we ship a single image, no fleet to
  # de-dup). Single DNS label, no dot, 59 chars (< the 63-char label cap).
  #
  # Safety — this cannot resurrect the Local Network privacy modal: that path is
  # ProcessInfo.hostName -> reverse-DNS of every local ADDRESS (address count, not
  # hostname length) and fires only under a zsh OSC 7 emission; the guest is bash
  # (the chsh provisioner above), so the path is dead regardless of \h length
  # (scutil --set HostName measured inert for that gate).
  # See research/03-analysis/ci-runner-prompt-width-forensics.md (mechanism +
  # probes + the gethostname spike) and local-network-privacy-forensics.md.
  provisioner "shell" {
    inline = [
      "sudo scutil --set HostName      xtty-ci-parity-runner-prompt-width-sjc22-be105-9E54E01C3448",
      "sudo scutil --set LocalHostName xtty-ci-parity-runner-prompt-width-sjc22-be105-9E54E01C3448",
      "sudo scutil --set ComputerName  xtty-ci-parity-runner-prompt-width-sjc22-be105-9E54E01C3448",
      "scutil --get HostName",
    ]
  }

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
