#!/bin/bash
# Mutation matrix for the guide-gate. Reverts each fix; the arm guarding it MUST go red.
# A fixture that never fails is decoration — this is what proves the suite isn't.
cd "$(dirname "$0")" || exit 1
trap 'rm -f _m.tmp _mi.tmp' EXIT
HOOKSRC=${HOOKSRC:-../.githooks/pre-push}
INSTSRC=${INSTSRC:-install-hooks.sh}
SUITE=${SUITE:-test-guide-gate.sh}
# A-C-mut (2026-07-18): two of this round's fixes live in install-hooks.sh, not pre-push -- $2
# lets a mutant target EITHER tracked source; omitted, it defaults to the real (unmutated) file.
run() { HOOK="$PWD/${1:-$HOOKSRC}" INST="$PWD/${2:-$INSTSRC}" bash "$SUITE" 2>&1 | grep -E '^❌' | sed 's/❌ *//;s/\..*//' | tr '\n' ' '; }

b=$(run "$HOOKSRC")
echo "BASELINE reds: [${b:-none}]"
[ -n "$b" ] && { echo "!! baseline is not green — fix that first"; exit 1; }
echo
printf '%-46s %s\n' "MUTANT (a fix, reverted)" "arms that catch it"
printf '%-46s %s\n' "$(printf '%.0s-' {1..46})" "------------------"

# A-15-3 (2026-07-18, both Codex- and Fable-caught): this driver had NO exit-code contract.
# "!! mutation failed" / "!! parse error" / "NONE <-- VACUOUS FIXTURE" all print-and-return 0
# from mut(), so the script always exited 0 -- make test-guide-gate/CI stayed green even if a
# hook refactor silently turned every mutant vacuous. `bad` accumulates every degraded mutant;
# the script now exits non-zero if any exist, so a fixture/mutant regression actually gates.
bad=0

mut() {
  cp "$HOOKSRC" _m.tmp
  python3 -c "
p='_m.tmp'; s=open(p).read()
$2
open(p,'w').write(s)" || { printf '%-46s !! mutation failed\n' "$1"; bad=$((bad+1)); return; }
  bash -n _m.tmp 2>/dev/null || { printf '%-46s !! parse error\n' "$1"; bad=$((bad+1)); return; }
  r=$(run _m.tmp)
  if [ -z "$r" ]; then
    printf '%-46s %s\n' "$1" "NONE  <-- VACUOUS FIXTURE"
    bad=$((bad+1))
  else
    printf '%-46s %s\n' "$1" "$r"
  fi
}

# A-C-mut: install-hooks.sh's own variant -- mutates INSTSRC instead of HOOKSRC, runs the suite
# with the pristine hook but the MUTATED installer (run's $2).
mut_inst() {
  cp "$INSTSRC" _mi.tmp
  python3 -c "
p='_mi.tmp'; s=open(p).read()
$2
open(p,'w').write(s)" || { printf '%-46s !! mutation failed\n' "$1"; bad=$((bad+1)); return; }
  bash -n _mi.tmp 2>/dev/null || { printf '%-46s !! parse error\n' "$1"; bad=$((bad+1)); return; }
  r=$(run "$HOOKSRC" _mi.tmp)
  if [ -z "$r" ]; then
    printf '%-46s %s\n' "$1" "NONE  <-- VACUOUS FIXTURE"
    bad=$((bad+1))
  else
    printf '%-46s %s\n' "$1" "$r"
  fi
}

mut "meter: read the blob, ignore the tree MODE"      "s=s.replace('    if [ \"\$mode\" = \"120000\" ]; then','    if false; then',1)"
mut "meter: count CHARACTERS, not bytes"              "s=s.replace('sz=\$(git cat-file -s \"\$blobid\" 2>/dev/null)','sz=\$(git cat-file blob \"\$blobid\" 2>/dev/null | wc -m | tr -d \\\" \\\")',1)"
mut "meter: unguard the empty-array (fail-OPEN)"      "s=s.replace('queue=(\${next[@]+\"\${next[@]}\"})','queue=(\"\${next[@]}\")',1)"
mut "meter: import depth off-by-one"                  "s=s.replace('[ \"\$hop\" -le \"\$MAXDEPTH\" ]','[ \"\$hop\" -lt \"\$MAXDEPTH\" ]',1)"
mut "meter: imports root-relative, not containing-file" "s=s.replace('          */*) next+=(\"\${real%/*}/\$imp\") ;;','          */*) next+=(\"\$imp\") ;;',1)"
mut "meter: fence/span-blind import parser"           "s=s.replace('/^[[:space:]]*\`\`\`/ { fence = !fence; next }','').replace('fence { next }','').replace('gsub(/\`[^\`]*\`/, \" \", line)','')"
mut "meter: do not weigh .claude/ eager roots"        "s=s.replace('    queue+=(\"\$r\")','    :',1)"
mut "meter: frontmatter check = grep ^paths:"         "s=s.replace('    NR == 1 { if (\$0 != \"---\") done = 1; next }','    NR == 1 { next }',1)"
mut "identity: any repo with a guide"                 "s=s.replace('[ \"\$(git config --get xtty.guide-gate 2>/dev/null || true)\" = \"true\" ] || exit 0','git cat-file -e HEAD:CLAUDE.md 2>/dev/null || exit 0',1)"
mut "ladder: tracking ref before first-push"          "s=s.replace('  if [ \"\$remote_oid\" = \"\$zero\" ]; then','  if [ \"\$remote_oid\" = \"\$zero\" ] && false; then',1)"
mut "ladder: no rung-0 (already-published escape)"    "s=s.replace('if [ -n \"\${canon_digest:-}\" ] && [ \"\$cur_digest\" = \"\$canon_digest\" ]','if false && [ \"\$cur_digest\" = \"\$canon_digest\" ]',1)"
mut "ladder: hardcode origin, ignore \$1"              "s=s.replace('REMOTE=\"\${1:-origin}\"','REMOTE=origin',1)"
mut "deletion: no vaporize FLOOR"                     "s=s.replace('  if [ \"\$bas\" -ge \"\$FLOOR\" ] && [ \"\$cur\" -lt \"\$FLOOR\" ]; then','  if false; then',1)"
mut "deletion: dangling is aggregate, not per-path"   "s=s.replace('      if resolve_entry \"\$base\" \"\$_d\" >/dev/null 2>&1; then vaporized=\"\$vaporized \$_d\"; fi','      vaporized=\"\$vaporized \$_d\"',1)"
mut "deletion: baseline EXISTENCE, not resolvability" "s=s.replace('      if resolve_entry \"\$base\" \"\$_d\" >/dev/null 2>&1; then','      if git ls-tree \"\$base\" -- \"\$_d\" 2>/dev/null | grep -q .; then',1)"
mut "latch: import_dangling counts as 'no guide'"     "s=s.replace('  if [ \"\$bas_status\" = root_missing ] && [ \"\$cur_status\" = root_missing ]; then continue; fi','  if [ \"\$bas_status\" != ok ] && [ \"\$cur_status\" != ok ]; then continue; fi',1)"
mut "fail-closed: drop the CEILING is_int guard"      "s=s.replace('if ! is_int \"\$CEILING\" || ! is_int \"\$FLOOR\"; then','if false; then',1)"
mut "alarm: restore the LYING ERR trap"               "s=s.replace('set -uo pipefail','set -uo pipefail\nset -E\ntrap \\'echo \\\"guide-gate: INTERNAL ERROR — refusing rather than failing open.\\\" >&2; exit 1\\' ERR',1)"
mut "ladder: trust a stale local tracking ref (A-15-1)" "s=s.replace('trust_stale_tracking_ref=no','trust_stale_tracking_ref=yes',1)"
mut "deletion: root check uses aggregate status again (A-15-2/A-15-2b)" "s=s.replace('if [ \"\$bas_root_gone\" = no ] && [ \"\$cur_root_gone\" = yes ]; then','if [ \"\$bas_status\" = ok ] && { [ \"\$cur_status\" = root_missing ] || [ \"\$cur_status\" = root_deleted ]; }; then',1)"
mut "ladder: rung-0 trusts a stale digest match regardless of commit (A-15-1b)" "s=s.replace('{ [ \"\$local_oid\" = \"\${canonical:-}\" ] || [ \"\$cur\" -le \"\$CEILING\" ]; }','{ true; }',1)"

echo
echo "════ cross-review round-1 mutants (Codex + inline Opus — 2026-07-18) ════"
mut "field-order: dangling reverts to a MIDDLE field, misaligning root_gone (A-C-1)" "s=s.replace('read -r cur cur_status cur_digest cur_root_gone cur_dangling <<<\"\$(resolve_guide \"\$local_oid\")\"','read -r cur cur_status cur_dangling cur_digest cur_root_gone <<<\"\$(resolve_guide \"\$local_oid\")\"',1)"
mut "frontmatter: paths: alone sets ok, no closing --- required (A-C-3)" "s=s.replace('/^paths:/ { saw_paths = 1; next }','/^paths:/ { ok = 1; saw_paths = 1; next }',1)"
# A-C-2's own mutant is RETIRED here (2026-07-18, stop-gate round): A-C-2e restructured the
# .claude/rules discovery loop so BOTH the .md and non-.md cases now funnel through ONE unified
# `if is_dir_symlink ...; then` call site -- the two-branch shape A-C-2's mutant targeted no longer
# exists, and its search string went vacuous (0 arms) the instant that restructuring landed. Its
# intent lives on, structurally superseded, in the "A-C-2e" mutant below (mirrors the A-15-2 ->
# A-15-2b retirement: a fixture/mutant that can never fail again is decoration, not proof).
mut "import: unsupported-shape disambiguation (ancestor OR terminal) removed entirely (A-C-2b/A-C-terminal)" "s=s.replace('if has_symlinked_ancestor \"\$oid\" \"\$p\" || is_dir_symlink \"\$oid\" \"\$p\" || is_gitlink \"\$oid\" \"\$p\"; then','if false; then',1)"
mut_inst "installer: hash-tracking removed, hand-merge gets clobbered again (A-C-5)" "s=s.replace('if [ -z \"\$recorded_hash\" ] || [ \"\$installed_hash\" != \"\$recorded_hash\" ]; then','if false; then',1)"
mut_inst "installer: worktree-scoped hooksPath misdiagnosed as global again (A-C-6)" "s=s.replace('if git config --worktree --get core.hooksPath >/dev/null 2>&1; then','if false; then',1)"

echo
echo "════ cross-review round-2 mutants (Codex + inline Opus — 2026-07-18) ════"
mut "seen: dedup reverts to SUFFIX match, false-positives on tail collision (A-C-seen)" "s=s.replace('[ \"\$sv\" = \"\$p\" ] && { already=yes; break; }','case \"\$sv\" in *\"\$p\") already=yes; break ;; esac',1)"
mut "rules: DIRECTORY symlink CHAIN (2+ hops) escapes detection undetected (A-C-2c)" "old='[ \"\$hops\" -lt 8 ]'
idx = s.rfind(old)
s = s[:idx] + '[ \"\$hops\" -lt 2 ]' + s[idx+len(old):]"
mut "empty queue: unresolved_symlink status discarded, reverts to root_missing (A-C-2d)" "s=s.replace('if [ \${#queue[@]} -eq 0 ]; then printf \'0 %s - yes none\' \"\$status\"; return; fi','if [ \${#queue[@]} -eq 0 ]; then printf \'0 root_missing - yes none\'; return; fi',1)"
mut "dangling: consumer reverts to comma-splitting, mismatches the unit-separator producer (A-C-comma)" "s=s.replace('IFS=\"\$DANG_SEP\" read -ra _dangs <<<\"\${cur_dangling%\$DANG_SEP}\"','IFS=, read -ra _dangs <<<\"\${cur_dangling%,}\"',1)"
mut_inst "installer: dangerous self-defeating recovery instruction re-added (A-C-5b)" "s=s.replace('echo \"hooks: this installer will keep refusing to touch it (safe by design — see A-C-5b) on\" >&2','echo \"hooks: this installer will keep refusing to touch it (safe by design — see A-C-5b) on\" >&2\n    echo \"hooks:        git config xtty.guide-gate-hook-sha \\\"\$(git hash-object \$TARGET)\\\"\" >&2',1)"

echo
echo "════ codex stop-gate mutants (2026-07-18, blocked session end) ════"
mut "rules: discovery-time check removed entirely, ALL directory symlinks/gitlinks escape (A-C-2/A-C-2e)" "s=s.replace('if is_dir_symlink \"\$oid\" \"\$r\" || is_gitlink \"\$oid\" \"\$r\"; then','if false; then',1)"
mut_inst "installer: XTTY_GUIDE_FORCE bypass removed, no real discard path exists (A-C-5c)" "s=s.replace('if [ -e \"\$TARGET\" ] && [ \"\${XTTY_GUIDE_FORCE:-}\" != \"1\" ]; then','if [ -e \"\$TARGET\" ]; then',1)"

echo
echo "════ codex-only final pass mutants (2026-07-18, user-requested single-model review) ════"
mut "gitlink/tree: resolve_entry treats a gitlink OR a bare-symlinked directory as a blob again (A-C-gitlink/A-C-tree)" "s=s.replace('case \"\$mode\" in 040000|160000) return 1 ;; esac','',1)"
mut "gitlink: has_symlinked_ancestor stops catching a gitlink ancestor (A-C-gitlink-ancestor)" "s=s.replace('case \"\$mode\" in 120000|160000) return 0 ;; esac','[ \"\$mode\" = \"120000\" ] && return 0',1)"
mut_inst "installer: physical-path containment check removed, symlinked hooks dir escapes (A-C-phys)" "s=s.replace('  \"\$common_dir_abs\"/*) : ;;   # genuinely inside our own git-common-dir tree -- safe','  *) : ;;',1)"
mut_inst "installer: arming-verify readback removed, silent config-write failure again (A-C-arm-verify)" "s=s.replace('if [ \"\$(git config --get xtty.guide-gate 2>/dev/null || true)\" != \"true\" ]; then','if false; then',1)"

echo
echo "════ codex stop-gate round 2 mutants (2026-07-18, blocked session end again) ════"
mut "symlink-gitlink: is_dir_symlink stops recognizing a terminal GITLINK (A-C-symlink-gitlink)" "s=s.replace('case \"\$mode\" in 040000|160000) return 0 ;; esac      # reached a directory OR a gitlink: success','[ \"\$mode\" = \"040000\" ] && return 0',1)"

if [ "$bad" -eq 0 ]; then
  echo
  echo "All mutants caught cleanly (0 vacuous, 0 failed)."
else
  echo
  echo "!! $bad mutant(s) vacuous or failed -- the mutation guarantee is broken. See '!!'/'NONE' rows above." >&2
  exit 1
fi
