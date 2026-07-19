#!/usr/bin/env bash
# Non-vacuous fail-closed drills for the two cross-review deterministic scripts
# (tasks 3.7/19 + the 12c semver check; emit-attestation-line's --line emitter,
# its TTY-gated stderr, and its trailing-arg rejection). Builds a throwaway git
# repo and runs the REAL committed scripts against constructed scenarios. Prints
# PASS/FAIL per drill.
set -uo pipefail

# resolve the committed scripts relative to THIS harness (it lives alongside them
# in scripts/), so the drills are reproducible from a clean clone — not tied to one
# checkout path.
REPO_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCOPE="$REPO_SCRIPTS/cross-review-scope.sh"
DIGEST="$REPO_SCRIPTS/cross-review-digest.sh"

T="$(mktemp -d)"
cd "$T"
git init -q
git config user.email t@t.t; git config user.name t
export GIT_AUTHOR_DATE="2026-01-01T00:00:00" GIT_COMMITTER_DATE="2026-01-01T00:00:00"

pass=0; fail=0
ok()   { echo "  PASS: $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL: $1"; fail=$((fail+1)); }
mk()   { mkdir -p "$(dirname "$1")"; printf '%s\n' "$2" > "$1"; }

# a pre-change baseline commit so every change has a real parent (base B)
mk README.md "baseline"; git add -A; git commit -qm "baseline"

echo "== Scenario A: docs-only change ⇒ SCOPE out (exit 0) =="
mk openspec/changes/docsonly/proposal.md "why";      git add -A; git commit -qm "docs: propose docsonly"
mk research/03-analysis/docsonly-note.md "finding";  git add -A; git commit -qm "docs: research"
mk AGENTS.md "tracker edit";                         git add -A; git commit -qm "docs: tracker"
"$SCOPE" docsonly; rc=$?
[ $rc -eq 0 ] && ok "docs-only ⇒ out (rc=0)" || bad "docs-only expected rc=0, got $rc"

echo "== Scenario B: change touching scripts/ + .claude/ ⇒ SCOPE in (exit 10) =="
mk openspec/changes/tooling/proposal.md "why";       git add -A; git commit -qm "docs: propose tooling"
mk scripts/newtool.sh "echo hi";                     git add -A; git commit -qm "feat: a script"
mk .claude/commands/xtty/foo.md "cmd";               git add -A; git commit -qm "feat: a command"
"$SCOPE" tooling; rc=$?
[ $rc -eq 10 ] && ok "tooling ⇒ in (rc=10)" || bad "tooling expected rc=10, got $rc"

echo "== Scenario C: range-omission (dir touched before proposal.md) ⇒ REFUSE (exit 2) =="
mk openspec/changes/early/notes.md "predates";       git add -A; git commit -qm "chore: early note"
mk openspec/changes/early/proposal.md "why";         git add -A; git commit -qm "docs: propose early"
"$SCOPE" early 2>/dev/null; rc=$?
[ $rc -eq 2 ] && ok "range-omission scope ⇒ refuse (rc=2)" || bad "range-omission scope expected rc=2, got $rc"
"$DIGEST" early 2>/dev/null; rc=$?
[ $rc -eq 2 ] && ok "range-omission digest ⇒ refuse (rc=2)" || bad "range-omission digest expected rc=2, got $rc"

echo "== Scenario D: digest invariance to bookkeeping (tick + attestation line + ledger) =="
mk openspec/changes/dig/proposal.md "why";           git add -A; git commit -qm "docs: propose dig"
mk openspec/changes/dig/design.md "how";
printf -- '- [ ] 1.1 build the thing\n- [ ] 5.2 human attestation task\n' > openspec/changes/dig/tasks.md
mk scripts/digtool.sh "echo reviewed";               git add -A; git commit -qm "feat: reviewed content"
D1="$("$DIGEST" dig)"; rc=$?
[ $rc -eq 0 ] && [ -n "$D1" ] && ok "digest computes on clean tree: ${D1:0:16}…" || bad "digest failed rc=$rc"
# now simulate the human attestation act: tick boxes + add the delimited line + add the advisory ledger
printf -- '- [x] 1.1 build the thing\n- [x] 5.2 human attestation task\n<!-- cross-review-attestation: base=%s head=deadbeef digest=%s reviewed=2026-01-02 -->\n' "abc123" "$D1" > openspec/changes/dig/tasks.md
mk openspec/changes/dig/cross-review-ledger.md "advisory findings, dismissals, rationale"
git add -A; git commit -qm "docs: attest + ledger (bookkeeping only)"
D2="$("$DIGEST" dig)"
[ "$D1" = "$D2" ] && ok "digest INVARIANT to tick+attestation+ledger" || bad "digest changed under bookkeeping ($D1 vs $D2)"

echo "== Scenario I (emit-attestation-line): --line matches independently-known ground truth, mutates nothing =="
# ground truth for base/head, derived independently of BOTH cross-review scripts (raw git only)
EXPECTED_B="$(git rev-parse "$(git log --diff-filter=A --format=%H -- openspec/changes/dig/proposal.md | tail -1)^")"
EXPECTED_HEAD="$(git rev-parse HEAD)"
LINE_OUT="$("$DIGEST" --line dig)"; rc=$?
[ $rc -eq 0 ] && ok "--line exits 0" || bad "--line expected rc=0, got $rc"
LINE_COUNT="$(printf '%s\n' "$LINE_OUT" | wc -l | tr -d ' ')"
[ "$LINE_COUNT" = "1" ] && ok "--line prints exactly one line to stdout" || bad "--line printed $LINE_COUNT lines"
GOT_BASE="$(printf '%s\n' "$LINE_OUT" | sed -n 's/.*base=\([^ ]*\) .*/\1/p')"
GOT_HEAD="$(printf '%s\n' "$LINE_OUT" | sed -n 's/.*head=\([^ ]*\) .*/\1/p')"
GOT_DIGEST="$(printf '%s\n' "$LINE_OUT" | sed -n 's/.*digest=\([^ ]*\) .*/\1/p')"
GOT_REVIEWED="$(printf '%s\n' "$LINE_OUT" | sed -n 's/.*reviewed=\([^ ]*\) .*/\1/p')"
[ "$GOT_BASE" = "$EXPECTED_B" ] && ok "--line base= matches ground truth derived independently of both scripts" || bad "--line base=$GOT_BASE != expected $EXPECTED_B"
[ "$GOT_HEAD" = "$EXPECTED_HEAD" ] && ok "--line head= matches git rev-parse HEAD" || bad "--line head=$GOT_HEAD != expected $EXPECTED_HEAD"
[ "$GOT_DIGEST" = "$D1" ] && ok "--line digest= matches default-mode stdout digest" || bad "--line digest=$GOT_DIGEST != default $D1"
case "$GOT_REVIEWED" in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ok "--line reviewed= is a YYYY-MM-DD date" ;;
  *) bad "--line reviewed= not a date: $GOT_REVIEWED" ;;
esac
BEFORE_HEAD="$(git rev-parse HEAD)"; BEFORE_STATUS="$(git status --porcelain)"
"$DIGEST" --line dig >/dev/null
AFTER_HEAD="$(git rev-parse HEAD)"; AFTER_STATUS="$(git status --porcelain)"
[ "$BEFORE_HEAD" = "$AFTER_HEAD" ] && [ "$BEFORE_STATUS" = "$AFTER_STATUS" ] && ok "--line makes no repository mutation" || bad "--line mutated repo state"

echo "== Scenario J (emit-attestation-line): default mode's stderr line is TTY-gated (silent when non-interactive) =="
OUT_ERR="$("$DIGEST" dig 2>&1 1>/dev/null)"
[ -z "$OUT_ERR" ] && ok "default mode emits nothing on stderr when non-interactive" || bad "expected empty stderr, got: $OUT_ERR"

echo "== Scenario K (emit-attestation-line): an unexpected trailing argument is rejected =="
"$DIGEST" dig extra-garbage 2>/dev/null; rc=$?
[ $rc -eq 2 ] && ok "trailing extra arg ⇒ refuse (rc=2)" || bad "trailing extra arg expected rc=2, got $rc"

echo "== Scenario E: digest CHANGES when a reviewed artifact is edited =="
mk openspec/changes/dig/design.md "how — MATERIALLY EDITED after attestation"; git add -A; git commit -qm "docs: edit reviewed design"
D3="$("$DIGEST" dig)"
[ "$D1" != "$D3" ] && ok "digest CHANGES on reviewed-artifact edit (fail-closed at archive)" || bad "digest failed to change on reviewed edit"

echo "== Scenario F: dirty tree ⇒ digest REFUSE (exit 2) =="
echo "uncommitted" >> openspec/changes/dig/design.md
"$DIGEST" dig 2>/dev/null; rc=$?
[ $rc -eq 2 ] && ok "dirty tree ⇒ refuse (rc=2)" || bad "dirty tree expected rc=2, got $rc"
git checkout -- openspec/changes/dig/design.md

echo "== Scenario G (12c): version resolution is numeric, not lexical =="
picked="$(printf '1.0.6\n1.0.10\n1.0.9\n' | sort -V | tail -1)"
[ "$picked" = "1.0.10" ] && ok "sort -V picks 1.0.10 > 1.0.9 > 1.0.6 (numeric)" || bad "version pick got '$picked'"
lexical="$(printf '1.0.6\n1.0.10\n1.0.9\n' | sort | tail -1)"
echo "     (lexical sort would wrongly pick '$lexical' — confirms -V is load-bearing)"

echo "== Scenario H (exempt-by-act, archive step-0 grep): attestation line singular + never rewritten =="
# the exact mechanical check the hand-authored archive ritual runs over the change's tasks.md:
sentinel='<!-- cross-review-attestation:'
exempt_by_act() { # cwd = repo; $1 = tasks path — echoes ok|fail
  local tasks="$1"
  local now adds dels
  now="$(grep -c "$sentinel" "$tasks" 2>/dev/null || true)"
  adds="$(git log -p -- "$tasks" | grep -c "^+.*$sentinel" || true)"
  dels="$(git log -p -- "$tasks" | grep -c "^-.*$sentinel" || true)"
  if [ "$now" -eq 1 ] && [ "$adds" -eq 1 ] && [ "$dels" -eq 0 ]; then echo ok; else echo "fail(now=$now adds=$adds dels=$dels)"; fi
}
# dig's tasks.md carries one attestation line, added once in the bookkeeping commit (Scenario D)
r="$(exempt_by_act openspec/changes/dig/tasks.md)"
[ "$r" = ok ] && ok "legit single-add attestation ⇒ exempt-by-act OK" || bad "legit attestation flagged: $r"
# now REWRITE the attestation line's digest in a later commit (the R8 attack)
sed -i '' "s/digest=$D1/digest=FORGEDVALUE/" openspec/changes/dig/tasks.md
git add -A; git commit -qm "docs: (illicit) rewrite the attestation digest"
r="$(exempt_by_act openspec/changes/dig/tasks.md)"
[ "$r" != ok ] && ok "rewritten attestation ⇒ exempt-by-act FAILS closed: $r" || bad "rewrite not detected"
# and a DELETE of the line
git revert -q --no-edit HEAD >/dev/null 2>&1 || git reset -q --hard HEAD~1  # back to one clean add
sed -i '' "/$sentinel/d" openspec/changes/dig/tasks.md
git add -A; git commit -qm "docs: (illicit) delete the attestation line"
r="$(exempt_by_act openspec/changes/dig/tasks.md)"
[ "$r" != ok ] && ok "deleted attestation ⇒ exempt-by-act FAILS closed: $r" || bad "delete not detected"

echo
echo "==== RESULT: $pass passed, $fail failed ===="
rm -rf "$T"
[ $fail -eq 0 ]
