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

# A-C-phys (2026-07-18, Codex-caught, final pass): the core.hooksPath guard above only catches
# GIT-CONFIG-level redirection. A raw FILESYSTEM symlink at <git-common-dir>/hooks (or any path
# component of it) achieves the identical cross-repo-harm outcome -- core.hooksPath stays unset,
# every check above passes, and a write below would land OUTSIDE this repository, possibly in a
# directory shared with unrelated repos (the exact "gate a stranger's project" harm arm 3 already
# tests for the config-level case). Verified by effect: a `.git/hooks -> /shared/hooks` symlink
# with core.hooksPath unset silently absorbed an install, and XTTY_GUIDE_FORCE=1 made it WORSE by
# also overwriting the shared file outright. This check is UNCONDITIONAL and runs BEFORE the FORCE
# gate below -- FORCE is scoped only to "is this content verifiably ours," never to "are we even
# writing inside our own repository," so it must never be able to bypass this.
common_dir_abs="$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)"
dest_abs="$(cd "$DEST" 2>/dev/null && pwd -P)"
case "$dest_abs" in
  "$common_dir_abs"/*) : ;;   # genuinely inside our own git-common-dir tree -- safe
  *)
    echo "hooks: $DEST does not physically resolve inside this repository's own git directory" >&2
    echo "hooks: ($common_dir_abs) — some path component (commonly <git-dir>/hooks itself) is a" >&2
    echo "hooks: FILESYSTEM symlink pointing OUTSIDE this repo. Installing there could affect" >&2
    echo "hooks: unrelated repositories sharing that location. Refusing UNCONDITIONALLY — this" >&2
    echo "hooks: is a cross-repository safety boundary, never bypassable by XTTY_GUIDE_FORCE." >&2
    exit 0
    ;;
esac

# A-C-5c (2026-07-18, Codex stop-gate-caught): A-C-5b's recovery message told the user to
# "explicitly re-run 'make hooks' to DISCARD it" -- but a bare re-run invokes this SAME installer,
# which hits this SAME mismatch branch and refuses AGAIN, forever. That instruction described a
# recovery path that DOES NOT EXIST -- verified by effect (running it twice: refused both times,
# byte-identical). The exact "recovery advice that leads nowhere" bug class this project fixed
# under A-15-7 for a different scope, reintroduced by A-C-5b's own fix. A real discard path needs
# an explicit signal ORTHOGONAL to a bare re-run: an env override, mirroring the hook's own
# XTTY_GUIDE_CEILING/XTTY_GUIDE_FLOOR idiom (never a default -- a silent env leak must never
# discard a stranger's hook, same reasoning as the ceiling parse living after the identity guard).
if [ -e "$TARGET" ] && [ "${XTTY_GUIDE_FORCE:-}" != "1" ]; then
  if ! grep -qF "$SENTINEL" "$TARGET" 2>/dev/null; then
    # A-15-6 (2026-07-18, Codex-caught): the old message said "merge by hand" but never told the
    # user to set the stamp themselves -- this installer path exits BEFORE stamping, so a hand
    # merge alone leaves the gate inert (the identity guard exits on an unstamped repo).
    echo "hooks: a FOREIGN pre-push hook already exists at $TARGET — not clobbering it." >&2
    echo "hooks: to arm the guide gate alongside it:" >&2
    echo "hooks:   1. merge the logic from $SRC into $TARGET by hand" >&2
    echo "hooks:   2. stamp this repo (this installer never wrote $TARGET, so it never stamps):" >&2
    echo "hooks:        git config xtty.guide-gate true" >&2
    echo "hooks:   This installer will leave $TARGET alone on every future run (see A-C-5/A-C-5b" >&2
    echo "hooks:   below) -- there is nothing else to record. Keep the merge current BY HAND when" >&2
    echo "hooks:   $SRC changes; this installer will never do it for you again, UNLESS you" >&2
    echo "hooks:   explicitly discard it: XTTY_GUIDE_FORCE=1 make hooks" >&2
    exit 0
  fi
  # A-C-5 (2026-07-18, Codex-caught): a substring-sentinel match alone cannot tell "an untouched
  # copy we installed" from "a human merged our source's text into a foreign hook" -- both contain
  # the sentinel. The old code treated ANY sentinel match as "our own copy, always safe to
  # re-copy," which SILENTLY DESTROYED a hand-merged foreign hook's logic on the very next routine
  # `make build`/`test`/etc. (not just an explicit `make hooks` -- `hooks` is an order-only
  # prerequisite of all of them), because A-15-6's warning above only cautioned against re-running
  # `make hooks` by name. Track OWNERSHIP by a recorded hash of what WE last wrote instead: only a
  # hash WE recorded ourselves (immediately after our own `install` below) counts as "verifiably
  # ours, safe to upgrade" (D2's "staleness impossible" guarantee) -- a first-ever install (no file
  # yet) also proceeds.
  # A-C-5b (2026-07-18, Codex-caught, round 2): A-C-5's OWN recovery message told the user to
  # manually run `git config xtty.guide-gate-hook-sha "$(git hash-object $TARGET)"` to "record a
  # hand-merge as ours" -- which makes `installed_hash == recorded_hash` on the VERY NEXT run,
  # which is EXACTLY the condition this guard treats as "verifiably our own install, safe to
  # re-copy." Verified by effect: a user who followed that printed instruction to the letter had
  # their merge silently destroyed by the next routine `make build`. There is no safe way for a
  # HUMAN-typed command to mark content as "ours" without also making it eligible for the very
  # overwrite it was meant to prevent -- so this key must ONLY ever be written by the installer's
  # own `install` step below, NEVER printed as a user-facing recovery instruction.
  installed_hash=$(git hash-object "$TARGET" 2>/dev/null || true)
  recorded_hash=$(git config --get xtty.guide-gate-hook-sha 2>/dev/null || true)
  if [ -z "$recorded_hash" ] || [ "$installed_hash" != "$recorded_hash" ]; then
    echo "hooks: $TARGET carries this project's sentinel but does NOT match what this installer" >&2
    echo "hooks: last wrote here (a hand-merge, or a manual edit since) — NOT overwriting it." >&2
    echo "hooks: this installer will keep refusing to touch it (safe by design — see A-C-5b) on" >&2
    echo "hooks: every bare re-run, including 'make hooks' — that is NOT a discard path, it hits" >&2
    echo "hooks: this exact refusal again. To actually DISCARD it and install the pristine tracked" >&2
    echo "hooks: hook, you must pass an explicit force signal (a bare re-run never does this):" >&2
    echo "hooks:     XTTY_GUIDE_FORCE=1 make hooks" >&2
    echo "hooks: There is no config command that marks a hand-edited file 'safe to keep AND" >&2
    echo "hooks: auto-upgrade' — those are contradictory. Back up any custom logic first." >&2
    exit 0
  fi
fi

# Own copy (verified via the recorded hash above) or none: always re-copy => staleness
# impossible, upgrades land.
install -m 755 "$SRC" "$TARGET" 2>/dev/null || exit 0
git config xtty.guide-gate-hook-sha "$(git hash-object "$TARGET" 2>/dev/null)" 2>/dev/null || true
git config xtty.guide-gate true 2>/dev/null || true   # the repo stamp the hook checks

# A-C-arm-verify (2026-07-18, Codex-caught, final pass): both config writes above swallow errors
# on purpose (this installer is CANNOT-FAIL — a transient lock/permission issue must never break a
# routine `make build`). But a silently-failed write left the hook FILE installed with no stamp —
# the hook's OWN identity guard then no-ops on every future push, and nothing ever told the user.
# Verified by effect: a pre-existing .git/config.lock made the arming write silently fail while
# the installer still exited 0. Read back what was actually recorded and print a non-fatal
# diagnostic when arming didn't stick, so "make hooks succeeded" and "this clone is actually
# armed" can't silently diverge.
if [ "$(git config --get xtty.guide-gate 2>/dev/null || true)" != "true" ]; then
  echo "hooks: WARNING — the hook was installed at $TARGET, but arming this repo" >&2
  echo "hooks: (git config xtty.guide-gate true) did NOT take effect — a concurrent git" >&2
  echo "hooks: process or a locked/read-only .git/config likely blocked the write. The gate" >&2
  echo "hooks: will NOT run until this is resolved. Re-run 'make hooks' once the contention" >&2
  echo "hooks: clears, or set it directly: git config xtty.guide-gate true" >&2
fi
exit 0
