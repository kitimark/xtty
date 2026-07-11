#!/usr/bin/env bash
#
# cross-review-digest.sh — the committed, deterministic REVIEWED-STATE DIGEST tool
# for the cross-model-review archive gate (add-cross-model-design-review, design D8).
#
# Prints a stable hex digest over a change's reviewed content — the content at
# HEAD of every file changed in the net B..HEAD range (a content hash, not a
# diff hash) — EXCLUDING EXACTLY the review's bookkeeping surfaces, so that
# recording the human attestation cannot self-invalidate the digest:
#   * the advisory ledger (openspec/changes/<name>/cross-review-ledger.md), and
#   * inside the change's tasks.md: the delimited attestation line(s) and checkbox
#     STATE — a tick flips [ ]<->[x] WITHOUT changing the digest, while editing a
#     task's TEXT does change it.
# Everything else in the reviewed range contributes, so any post-attestation edit
# to a reviewed artifact changes the recomputed digest and forces re-attestation.
#
# REFUSES on a dirty tree/index (the attestation must bind a COMMITTED state).
#
# Usage:  scripts/cross-review-digest.sh <change-name>
# Output: a 64-hex sha256 digest on stdout (and NOTHING else on stdout).
# Exit:   0 ok; 2 refuse (dirty tree, unresolved/omitted range, missing input).
#
# Deterministic; trust class of git/openspec (committed, human-reviewable). Keep
# the base-resolution block byte-identical with scripts/cross-review-scope.sh.
set -euo pipefail

die() { echo "cross-review-digest: $*" >&2; exit 2; }

CHANGE="${1:?usage: cross-review-digest.sh <change-name>}"
CHANGE_DIR="openspec/changes/$CHANGE"
[ -d "$CHANGE_DIR" ] || die "no such change dir: $CHANGE_DIR"

# refuse on a dirty tree/index/untracked — the attestation binds a COMMITTED state
[ -z "$(git status --porcelain)" ] || \
  die "working tree is dirty — commit or stash before computing the reviewed-state digest"

# --- base resolution (positional git rule; fail-closed range-omission assert) ---
# B = parent of the commit that INTRODUCED the change (added its proposal.md).
prop_add="$(git log --diff-filter=A --format=%H -- "$CHANGE_DIR/proposal.md" | tail -1)"
[ -n "$prop_add" ] || die "cannot find the commit that added $CHANGE_DIR/proposal.md"
first_dir="$(git log --format=%H -- "$CHANGE_DIR" | tail -1)"
[ "$prop_add" = "$first_dir" ] || \
  die "range-omission: $CHANGE_DIR was touched before its proposal.md ($first_dir precedes $prop_add) — refusing rather than silently narrowing the reviewed range"
B="$(git rev-parse "${prop_add}^" 2>/dev/null)" || die "the proposal.md-introducing commit has no parent"

LEDGER="$CHANGE_DIR/cross-review-ledger.md"
TASKS="$CHANGE_DIR/tasks.md"

# normalize the bookkeeping surfaces out of tasks.md content:
#   - drop the delimited attestation line(s)
#   - canonicalize checkbox STATE to [ ] (a tick must not change the digest)
normalize_tasks() {
  sed -e '/<!-- cross-review-attestation:/d' \
      -e 's/^\([[:space:]]*-[[:space:]]*\)\[[ xX]\]/\1[ ]/'
}

digest_stream() {
  # deterministic: C-sorted path list; each path (NUL-framed) followed by its HEAD
  # content — the ledger excluded entirely, tasks.md normalized, a deleted path a marker.
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    [ "$p" = "$LEDGER" ] && continue
    printf '\0PATH\0%s\0' "$p"
    if git cat-file -e "HEAD:$p" 2>/dev/null; then
      if [ "$p" = "$TASKS" ]; then git show "HEAD:$p" | normalize_tasks
      else git show "HEAD:$p"; fi
    else
      printf 'DELETED'
    fi
  done < <(git diff --name-only "$B"..HEAD | LC_ALL=C sort)
}

digest_stream | shasum -a 256 | awk '{print $1}'
