#!/bin/bash
# Mutation matrix for the guide-gate. Reverts each fix; the arm guarding it MUST go red.
# A fixture that never fails is decoration — this is what proves the suite isn't.
cd "$(dirname "$0")" || exit 1
HOOKSRC=${HOOKSRC:-pre-push-v18}
SUITE=${SUITE:-suite-v18.sh}
run() { HOOK="$PWD/$1" bash "$SUITE" 2>&1 | grep -E '^❌' | sed 's/❌ *//;s/\..*//' | tr '\n' ' '; }

b=$(run "$HOOKSRC")
echo "BASELINE reds: [${b:-none}]"
[ -n "$b" ] && { echo "!! baseline is not green — fix that first"; exit 1; }
echo
printf '%-46s %s\n' "MUTANT (a fix, reverted)" "arms that catch it"
printf '%-46s %s\n' "$(printf '%.0s-' {1..46})" "------------------"

mut() {
  cp "$HOOKSRC" _m.tmp
  python3 -c "
p='_m.tmp'; s=open(p).read()
$2
open(p,'w').write(s)" || { printf '%-46s !! mutation failed\n' "$1"; return; }
  bash -n _m.tmp 2>/dev/null || { printf '%-46s !! parse error\n' "$1"; return; }
  r=$(run _m.tmp)
  printf '%-46s %s\n' "$1" "${r:-NONE  <-- VACUOUS FIXTURE}"
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
rm -f _m.tmp
