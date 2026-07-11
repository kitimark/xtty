#!/usr/bin/env bash
#
# cross-review-scope.sh — the committed, deterministic MECHANICAL SCOPE CLASSIFIER
# for the cross-model-review archive gate (add-cross-model-design-review, design D5/D7).
#
# Decides whether a change is IN SCOPE for the human-attested cross-model review
# gate, from the change's changed PATHS ONLY — never a model judgment. A change
# that touches ANY path outside a fixed allowlist of documentation/tracker
# surfaces is IN SCOPE; an unrecognized or ambiguous path defaults to IN SCOPE
# (fail-closed). A change all of whose changed paths fall inside the allowlist
# (pure docs, tracker reconcile, a rename) is OUT OF SCOPE — eligible for the
# single-agent coherence review alone.
#
# The allowlist deliberately errs narrow: over-inclusion costs one review;
# under-inclusion is a gate bypass. THIS SCRIPT is the authority on the patterns.
#
# Usage:  scripts/cross-review-scope.sh <change-name>
# Output: a base..HEAD line + a "SCOPE: in|out …" verdict (+ the offending paths).
# Exit:   0  out of scope (the gate does not apply)
#         10 in scope   (the gate applies) — including on any ambiguous path
#         2  refuse      (the range cannot be resolved safely — e.g. a commit
#            predates the change's proposal.md; fail-closed, never silently narrow)
#
# Deterministic; trust class of git/openspec (committed, human-reviewable). Keep
# the base-resolution block byte-identical with scripts/cross-review-digest.sh.
set -euo pipefail

die() { echo "cross-review-scope: $*" >&2; exit 2; }

CHANGE="${1:?usage: cross-review-scope.sh <change-name>}"
CHANGE_DIR="openspec/changes/$CHANGE"
[ -d "$CHANGE_DIR" ] || die "no such change dir: $CHANGE_DIR"

# --- base resolution (positional git rule; fail-closed range-omission assert) ---
# B = parent of the commit that INTRODUCED the change (added its proposal.md).
prop_add="$(git log --diff-filter=A --format=%H -- "$CHANGE_DIR/proposal.md" | tail -1)"
[ -n "$prop_add" ] || die "cannot find the commit that added $CHANGE_DIR/proposal.md"
first_dir="$(git log --format=%H -- "$CHANGE_DIR" | tail -1)"
[ "$prop_add" = "$first_dir" ] || \
  die "range-omission: $CHANGE_DIR was touched before its proposal.md ($first_dir precedes $prop_add) — refusing rather than silently narrowing the reviewed range"
B="$(git rev-parse "${prop_add}^" 2>/dev/null)" || die "the proposal.md-introducing commit has no parent"

# --- fixed allowlist of OUT-OF-SCOPE documentation/tracker surfaces ---
allowlisted() {
  case "$1" in
    openspec/changes/*) return 0 ;;  # change prose artifacts, spec deltas, advisory ledger
    research/*)         return 0 ;;
    AGENTS.md|CLAUDE.md|HISTORY.md|README.md) return 0 ;;
    packer/README.md)   return 0 ;;
    *) return 1 ;;                    # anything else (incl. ambiguous) ⇒ in scope
  esac
}

paths="$(git diff --name-only "$B"..HEAD)"
n_paths="$(printf '%s\n' "$paths" | grep -c . || true)"
in_scope=()
while IFS= read -r p; do
  [ -z "$p" ] && continue
  allowlisted "$p" || in_scope+=("$p")
done <<< "$paths"

echo "base ${B:0:12} .. HEAD  (${n_paths} changed path(s))"
if [ "${#in_scope[@]}" -gt 0 ]; then
  echo "SCOPE: in — ${#in_scope[@]} path(s) outside the docs/tracker allowlist:"
  printf '  %s\n' "${in_scope[@]}"
  exit 10
fi
echo "SCOPE: out — every changed path is inside the docs/tracker allowlist (single-agent review suffices)"
exit 0
