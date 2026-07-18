#!/bin/bash
# `make hooks` — arm this clone. CANNOT FAIL (always exit 0); order-only, phony.
set -u
SENTINEL='xtty-guide-gate v13'
SRC="${1:?source hook}"

git rev-parse --git-dir >/dev/null 2>&1 || exit 0          # not a git repo: no-op

DEST="$(git rev-parse --git-common-dir)/hooks"             # shared by linked worktrees; checkout cannot reach it

# A-2: NEVER write into a hooks dir we do not own.
# `git rev-parse --git-path hooks` FOLLOWS core.hooksPath — including a GLOBAL one,
# which is the user's global hooks dir. Installing there arms the gate for EVERY
# repository they push. So: resolve OUR OWN git dir, and if core.hooksPath is set
# at all, git will not look there — warn and STOP rather than leak the gate out.
# A-15-7 (2026-07-18, Codex-caught, round 2): the previous recovery advice told GLOBAL-scope
# users to set a repo-LOCAL override pointing at DEST -- but this guard only checked WHETHER
# core.hooksPath was set at all, never WHAT it resolved to, so that override re-entered the
# same refusal branch forever (a reproducible infinite loop: follow the advice, still refused).
# Fix: resolve what core.hooksPath ACTUALLY points at (`git rev-parse --git-path hooks`, which
# follows local-over-global-over-system precedence exactly like git itself does when running a
# real hook) and compare it to DEST. If they're the SAME directory, a local override already
# neutralized the foreign/global setting for THIS repo -- proceed and install there for real.
if git config --get core.hooksPath >/dev/null 2>&1; then
  effective="$(git rev-parse --git-path hooks 2>/dev/null)"
  dest_abs="$(mkdir -p "$DEST" 2>/dev/null; cd "$DEST" 2>/dev/null && pwd -P)"
  effective_abs="$(cd "$effective" 2>/dev/null && pwd -P)"    # do NOT mkdir a hooksPath we may still refuse
  if [ -n "$dest_abs" ] && [ -n "$effective_abs" ] && [ "$dest_abs" = "$effective_abs" ]; then
    : # core.hooksPath is set, but a local override already resolves it back to OUR OWN dest —
      # git will read hooks from exactly where we're about to install. Safe: fall through.
  else
    cfg=$(git config --get core.hooksPath 2>/dev/null)
    [ -z "$cfg" ] && cfg='(empty — git searches the worktree root)'
    echo "hooks: core.hooksPath is set ($cfg) — git will not read this repo's own hooks dir." >&2
    echo "hooks: NOT installing (refusing to write into a hooks dir this project does not own)." >&2
    # A-C-6 (2026-07-18, Pass-C-caught, empirically verified): a WORKTREE-scoped override
    # (`git config --worktree core.hooksPath …`, needs extensions.worktreeConfig) is invisible to
    # `git config --local --get` -- the old two-way local/global check misdiagnosed it as global
    # and printed `git config core.hooksPath "$DEST"` as the fix, which writes LOCAL scope and is
    # silently outranked by the worktree-scoped value (confirmed: git rev-parse --git-path hooks
    # was UNCHANGED after running that exact command) -- the same "recovery advice that leads
    # nowhere" bug class A-15-7 already fixed for the global-vs-local case, in a third scope.
    if git config --worktree --get core.hooksPath >/dev/null 2>&1; then
      echo "hooks: it is set for THIS WORKTREE (git config --worktree) -- unset it there:" >&2
      echo "hooks:     git config --worktree --unset core.hooksPath   # then re-run make hooks" >&2
    elif git config --local --get core.hooksPath >/dev/null 2>&1; then
      echo "hooks: to arm the gate, UNSET core.hooksPath for this repo:" >&2
      echo "hooks:     git config --unset core.hooksPath   # then re-run make hooks" >&2
    else
      echo "hooks: it is set GLOBALLY (or via system config), not locally -- a local unset won't remove it." >&2
      echo "hooks: to arm the gate for THIS repo only, add a repo-LOCAL override that restores the default:" >&2
      echo "hooks:     git config core.hooksPath \"$DEST\"   # then re-run make hooks" >&2
    fi
    echo "hooks: (do NOT copy the hook into a shared/global hooks dir — it would run for" >&2
    echo "hooks:  every repository you push, gating strangers' projects with this ceiling.)" >&2
    exit 0
  fi
fi

mkdir -p "$DEST" 2>/dev/null || exit 0
TARGET="$DEST/pre-push"

if [ -e "$TARGET" ]; then
  if ! grep -qF "$SENTINEL" "$TARGET" 2>/dev/null; then
    # A-15-6 (2026-07-18, Codex-caught): the old message said "merge by hand" but never told the
    # user to set the stamp themselves -- this installer path exits BEFORE stamping, so a hand
    # merge alone leaves the gate inert (the identity guard exits on an unstamped repo).
    echo "hooks: a FOREIGN pre-push hook already exists at $TARGET — not clobbering it." >&2
    echo "hooks: to arm the guide gate alongside it:" >&2
    echo "hooks:   1. merge the logic from $SRC into $TARGET by hand" >&2
    echo "hooks:   2. record what you merged, so a routine 'make hooks'/'make build' etc. never" >&2
    echo "hooks:      silently overwrites it later (this installer never wrote $TARGET before, so" >&2
    echo "hooks:      it has nothing recorded to compare against — see A-C-5 below):" >&2
    echo "hooks:        git config xtty.guide-gate-hook-sha \"\$(git hash-object $TARGET)\"" >&2
    echo "hooks:        git config xtty.guide-gate true" >&2
    exit 0
  fi
  # A-C-5 (2026-07-18, Codex-caught): a substring-sentinel match alone cannot tell "an untouched
  # copy we installed" from "a human merged our source's text into a foreign hook" -- both contain
  # the sentinel. The old code treated ANY sentinel match as "our own copy, always safe to
  # re-copy," which SILENTLY DESTROYED a hand-merged foreign hook's logic on the very next routine
  # `make build`/`test`/etc. (not just an explicit `make hooks` -- `hooks` is an order-only
  # prerequisite of all of them), because A-15-6's warning above only cautioned against re-running
  # `make hooks` by name. Track OWNERSHIP by a recorded hash of what WE last wrote instead: if the
  # sentinel is present but there's no recorded hash (we never wrote here) or it doesn't match
  # what's on disk NOW (edited/merged since), this is not verifiably our last install -- refuse,
  # don't clobber. Only a hash match (a genuine prior install of ours, safe to upgrade -- D2's
  # "staleness impossible" guarantee) or a first-ever install (no file yet) proceeds.
  installed_hash=$(git hash-object "$TARGET" 2>/dev/null || true)
  recorded_hash=$(git config --get xtty.guide-gate-hook-sha 2>/dev/null || true)
  if [ -z "$recorded_hash" ] || [ "$installed_hash" != "$recorded_hash" ]; then
    echo "hooks: $TARGET carries this project's sentinel but does NOT match what this installer" >&2
    echo "hooks: last wrote here (a hand-merge, or a manual edit since) — NOT overwriting it." >&2
    echo "hooks: to arm the gate, either:" >&2
    echo "hooks:   1. re-run 'make hooks' after backing up any custom logic elsewhere (this" >&2
    echo "hooks:      OVERWRITES $TARGET with the pristine tracked hook), or" >&2
    echo "hooks:   2. keep it as-is and record it as ours so future runs leave it alone:" >&2
    echo "hooks:        git config xtty.guide-gate-hook-sha \"$installed_hash\"" >&2
    echo "hooks:        git config xtty.guide-gate true" >&2
    exit 0
  fi
fi

# Own copy (verified via the recorded hash above) or none: always re-copy => staleness
# impossible, upgrades land.
install -m 755 "$SRC" "$TARGET" 2>/dev/null || exit 0
git config xtty.guide-gate-hook-sha "$(git hash-object "$TARGET" 2>/dev/null)" 2>/dev/null || true
git config xtty.guide-gate true 2>/dev/null || true   # the repo stamp the hook checks
exit 0
