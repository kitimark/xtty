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
if git config --get core.hooksPath >/dev/null 2>&1; then
  cfg=$(git config --get core.hooksPath 2>/dev/null)
  [ -z "$cfg" ] && cfg='(empty — git searches the worktree root)'
  echo "hooks: core.hooksPath is set ($cfg) — git will not read this repo's own hooks dir." >&2
  echo "hooks: NOT installing (refusing to write into a hooks dir this project does not own)." >&2
  # A-15-5 (2026-07-18, Codex-caught): "git config --unset core.hooksPath" only touches the
  # LOCAL scope. When the value is inherited from GLOBAL (or system) config -- the motivating
  # case this whole guard exists for -- that unset is a silent no-op and every future `make
  # hooks` still declines. Detect scope and give the recovery that actually works for it.
  if git config --local --get core.hooksPath >/dev/null 2>&1; then
    echo "hooks: to arm the gate, UNSET core.hooksPath for this repo:" >&2
    echo "hooks:     git config --unset core.hooksPath   # then re-run make hooks" >&2
  else
    echo "hooks: it is set GLOBALLY (or via system config), not locally -- a local unset won't remove it." >&2
    echo "hooks: to arm the gate for THIS repo only, add a repo-LOCAL override that restores the default:" >&2
    echo "hooks:     git config core.hooksPath \"\$(git rev-parse --git-common-dir)/hooks\"   # then re-run make hooks" >&2
  fi
  echo "hooks: (do NOT copy the hook into a shared/global hooks dir — it would run for" >&2
  echo "hooks:  every repository you push, gating strangers' projects with this ceiling.)" >&2
  exit 0
fi

DEST="$(git rev-parse --git-common-dir)/hooks"             # shared by linked worktrees; checkout cannot reach it
mkdir -p "$DEST" 2>/dev/null || exit 0
TARGET="$DEST/pre-push"

if [ -e "$TARGET" ] && ! grep -qF "$SENTINEL" "$TARGET" 2>/dev/null; then
  # A-15-6 (2026-07-18, Codex-caught): the old message said "merge by hand" but never told the
  # user to set the stamp themselves -- this installer path exits BEFORE stamping, so a hand
  # merge alone leaves the gate inert (the identity guard exits on an unstamped repo). And
  # blindly re-running `make hooks` afterward is UNSAFE: if the merged file happens to contain
  # our sentinel text, the NEXT run would classify it as our own copy and OVERWRITE the merge.
  echo "hooks: a FOREIGN pre-push hook already exists at $TARGET — not clobbering it." >&2
  echo "hooks: to arm the guide gate alongside it:" >&2
  echo "hooks:   1. merge the logic from $SRC into $TARGET by hand" >&2
  echo "hooks:   2. stamp this repo yourself (this installer never wrote $TARGET, so it never stamps):" >&2
  echo "hooks:        git config xtty.guide-gate true" >&2
  echo "hooks:   Do NOT just re-run 'make hooks' afterward — if the merged file contains this" >&2
  echo "hooks:   installer's sentinel text, a later run will treat it as OUR copy and OVERWRITE" >&2
  echo "hooks:   your merge. Edit $TARGET directly for any future update instead." >&2
  exit 0
fi

# Own copy (or none): always re-copy => staleness impossible, upgrades land.
install -m 755 "$SRC" "$TARGET" 2>/dev/null || exit 0
git config xtty.guide-gate true 2>/dev/null || true   # the repo stamp the hook checks
exit 0
