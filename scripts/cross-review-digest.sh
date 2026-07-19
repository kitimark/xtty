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
# Usage:  scripts/cross-review-digest.sh [--line] <change-name>
# Output: default — ONLY the 64-hex sha256 digest on stdout, exactly as before
#         this tool grew a --line mode (no stderr emission of any kind on the
#         default path — an earlier TTY-gated variant was tried and rejected:
#         `[ -t 2 ]` detects a terminal transport, not a human actor, and a
#         PTY-wrapped invocation (script(1), an agent runner, tmux) defeats it,
#         so the only reliable boundary is to never emit the line unasked).
#         --line — ONLY the ready-to-paste attestation line on stdout (for
#         | pbcopy); this is the sole way to obtain it. Every field is
#         derived, never authored: base and the digest are already computed
#         here; head and the reviewed date are each resolved once and reused
#         for both the digest traversal and the emitted line, with a re-check
#         that HEAD/cleanliness didn't move mid-computation. Print-only
#         convenience — this tool never writes the line into a task file,
#         never ticks the attestation task, and never commits
#         (openspec/changes/emit-attestation-line/design.md; the ADDED
#         cross-model-review spec requirement of the same name). Source a
#         pasted line only from a command YOU ran yourself in your own
#         terminal — one sitting in a model's transcript or already on the
#         clipboard is not attestable provenance.
# Exit:   0 ok; 2 refuse (dirty tree, unresolved/omitted range, missing input,
#         extra positional args, a HEAD/cleanliness change mid-computation, or
#         a `git diff`/`git status` operational failure).
#
# Deterministic; trust class of git/openspec (committed, human-reviewable). Keep
# the base-resolution block byte-identical with scripts/cross-review-scope.sh.
set -euo pipefail

die() { echo "cross-review-digest: $*" >&2; exit 2; }

LINE_ONLY=0
if [ "${1:-}" = "--line" ]; then
  LINE_ONLY=1
  shift
fi

CHANGE="${1:?usage: cross-review-digest.sh [--line] <change-name>}"
shift
[ $# -eq 0 ] || die "unexpected extra argument(s): $*"
CHANGE_DIR="openspec/changes/$CHANGE"
[ -d "$CHANGE_DIR" ] || die "no such change dir: $CHANGE_DIR"

# refuse on a dirty tree/index/untracked — the attestation binds a COMMITTED state
clean_tree() {
  local out
  out="$(git status --porcelain)" || return 1
  [ -z "$out" ]
}
clean_tree || die "working tree is dirty — commit or stash before computing the reviewed-state digest"

# pin ONE HEAD OID for the whole run — the digest traversal and the emitted
# head= field must read the same snapshot, not two separately-resolved HEADs
HEAD_SHA="$(git rev-parse HEAD)" || die "cannot resolve HEAD"

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
  # deterministic: C-sorted path list, captured and exit-checked BEFORE the
  # loop rather than piped in via process substitution — a process
  # substitution's producer exit status is not propagated to the consuming
  # loop, so a failing `git diff` could otherwise silently drive zero
  # iterations and let an empty-input digest exit 0, as if there were no
  # reviewed content at all. Each path (NUL-framed) is followed by its
  # pinned-HEAD content — the ledger excluded entirely, tasks.md normalized,
  # a deleted path a marker.
  paths="$(git diff --name-only "$B".."$HEAD_SHA")" || die "git diff failed to enumerate the reviewed range"
  printf '%s\n' "$paths" | LC_ALL=C sort | while IFS= read -r p; do
    [ -z "$p" ] && continue
    [ "$p" = "$LEDGER" ] && continue
    printf '\0PATH\0%s\0' "$p"
    if git cat-file -e "$HEAD_SHA:$p" 2>/dev/null; then
      if [ "$p" = "$TASKS" ]; then git show "$HEAD_SHA:$p" | normalize_tasks
      else git show "$HEAD_SHA:$p"; fi
    else
      printf 'DELETED'
    fi
  done
}

DIGEST="$(digest_stream | shasum -a 256 | awk '{print $1}')"
REVIEWED_DATE="$(date +%F)" || die "cannot resolve the current date"

# re-check nothing moved under us between the initial checks and here — closes
# a TOCTOU window where a concurrent commit could bind a digest from one
# snapshot to a head= from another
[ "$(git rev-parse HEAD)" = "$HEAD_SHA" ] || die "HEAD moved during digest computation — refusing a torn snapshot"
clean_tree || die "working tree became dirty during digest computation — refusing a torn snapshot"

LINE="<!-- cross-review-attestation: base=$B head=$HEAD_SHA digest=$DIGEST reviewed=$REVIEWED_DATE -->"

if [ "$LINE_ONLY" -eq 1 ]; then
  echo "$LINE"
else
  echo "$DIGEST"
fi
