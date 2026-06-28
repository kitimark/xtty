#!/usr/bin/env bash
# bootstrap-swiftterm.sh — prepare the patched SwiftTerm for building (P4b-2).
#
# xtty needs two read-only accessors compiled INSIDE SwiftTerm's module
# (getScrollInvariantCursorLocation / scrollbackBase — they read internal buffer
# fields). Rather than maintain a fork repo, we pin upstream SwiftTerm as a git
# submodule (external/SwiftTerm @ v1.13.0, pristine) and drop our add-only
# accessor file into its source tree at build-prep time. This is the SwiftPM
# equivalent of Playwright's pin-upstream + in-repo-patch model; see
# research/03-analysis/swiftterm-fork-vs-patch-strategy.md.
#
# Run this once after cloning (and after any submodule update). Idempotent.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
submodule="$repo_root/external/SwiftTerm"
accessor_src="$repo_root/patches/swiftterm/XttyAccessors.swift"
accessor_dst="$submodule/Sources/SwiftTerm/XttyAccessors.swift"

# 1. Ensure the submodule is checked out (no-op if already present).
if [ ! -f "$submodule/Package.swift" ]; then
  echo "==> initializing the SwiftTerm submodule"
  git -C "$repo_root" submodule update --init external/SwiftTerm
fi

# 2. Drop in the add-only accessor file (overwrite to stay in sync with patches/).
echo "==> installing XttyAccessors.swift into the SwiftTerm module"
cp "$accessor_src" "$accessor_dst"

echo "==> done. XttyCore/Package.swift points at the local submodule; build as usual."
echo "    (re-run after 'git submodule update' or editing patches/swiftterm/XttyAccessors.swift)"
