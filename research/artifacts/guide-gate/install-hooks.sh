#!/bin/bash
# `make hooks` — arm this clone. CANNOT FAIL (always exit 0); order-only, phony.
set -u
SENTINEL='xtty-guide-gate v13'
SRC="${1:?source hook}"

git rev-parse --git-dir >/dev/null 2>&1 || exit 0          # not a git repo: no-op

# A-2: NEVER write into a hooks dir we do not own.
# `git rev-parse --git-path hooks` FOLLOWS core.hooksPath — including a GLOBAL one,
# which is the user's global hooks dir. Installing there arms the gate for EVERY
# repository they push. So: resolve OUR OWN git dir, and if core.hooksPath is set
# at all, git will not look there — warn and STOP rather than leak the gate out.
if cfg=$(git config --get core.hooksPath 2>/dev/null) && [ -n "$cfg" ]; then
  echo "hooks: core.hooksPath is set ($cfg) — git will not read this repo's own hooks dir." >&2
  echo "hooks: NOT installing (refusing to write into a hooks dir this project does not own)." >&2
  echo "hooks: to arm the guide gate: unset it, or copy $SRC into $cfg yourself." >&2
  exit 0
fi

DEST="$(git rev-parse --git-common-dir)/hooks"             # shared by linked worktrees; checkout cannot reach it
mkdir -p "$DEST" 2>/dev/null || exit 0
TARGET="$DEST/pre-push"

if [ -e "$TARGET" ] && ! grep -qF "$SENTINEL" "$TARGET" 2>/dev/null; then
  echo "hooks: a FOREIGN pre-push hook already exists at $TARGET — not clobbering it." >&2
  echo "hooks: merge $SRC into it by hand to arm the guide gate." >&2
  exit 0
fi

# Own copy (or none): always re-copy => staleness impossible, upgrades land.
install -m 755 "$SRC" "$TARGET" 2>/dev/null || exit 0
exit 0
