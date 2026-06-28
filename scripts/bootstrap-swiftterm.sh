#!/usr/bin/env bash
# bootstrap-swiftterm.sh — reconstitute the patched SwiftTerm for building (P4b-2).
#
# xtty needs two read-only accessors compiled INSIDE SwiftTerm's module
# (getScrollInvariantCursorLocation / scrollbackBase — they read internal buffer
# fields). Rather than a fork repo OR a submodule (the wrong primitive for a
# dependency you patch), we follow Playwright's actual model: track only the patch
# + the pin + this script, and reconstitute the upstream tree as a GITIGNORED clone
# (external/SwiftTerm is in .gitignore). See
# research/03-analysis/swiftterm-fork-vs-patch-strategy.md.
#
# Run this once after cloning, and after editing the pin or the accessor file.
# Idempotent; enforces the pinned ref every run so it can't drift.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
checkout="$repo_root/external/SwiftTerm"
patch="$repo_root/patches/swiftterm/xtty-accessors.diff"

# The pin: UPSTREAM_URL + UPSTREAM_REF (the single source of truth).
# shellcheck source=../patches/swiftterm/UPSTREAM_CONFIG.sh
source "$repo_root/patches/swiftterm/UPSTREAM_CONFIG.sh"

# 1. Clone the upstream into the gitignored checkout if it isn't there yet.
if [ ! -d "$checkout/.git" ]; then
  echo "==> cloning SwiftTerm into external/SwiftTerm (gitignored)"
  rm -rf "$checkout"
  git clone "$UPSTREAM_URL" "$checkout"
fi

# 2. Enforce the pinned ref and restore a PRISTINE upstream tree (idempotent — so
#    the checkout can't drift and so the patch always applies onto a clean base).
echo "==> pinning SwiftTerm to $UPSTREAM_REF (pristine)"
git -C "$checkout" fetch --tags --quiet origin
git -C "$checkout" -c advice.detachedHead=false checkout --quiet "$UPSTREAM_REF"
git -C "$checkout" clean -fdq        # drop a previously-applied patch (untracked add)

# 3. Apply the add-only patch (Playwright-style: a tracked .diff, git apply).
echo "==> applying patches/swiftterm/xtty-accessors.diff"
git -C "$checkout" apply "$patch"

echo "==> done. external/SwiftTerm @ $UPSTREAM_REF + xtty-accessors.diff applied."
echo "    XttyCore/Package.swift points at the local checkout; build as usual."
echo "    (re-run after editing patches/swiftterm/UPSTREAM_CONFIG.sh or xtty-accessors.diff)"
echo "    (to edit the patch: change it in a pristine checkout, then regenerate the .diff)"
