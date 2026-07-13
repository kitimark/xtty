#!/bin/bash
# Mutation matrix: revert each fix; the arm that guards it MUST go red.
# A fixture that never fails is decoration.
cd /Users/markmark/.claude/jobs/2e729592/tmp || exit 1
SRC=pre-push-v13

run() { HOOK="$1" bash suite-v13.sh 2>&1 | grep -E '^❌' | sed 's/❌ *//;s/ *want=.*//' | tr '\n' ';' ; }

echo "BASELINE (unmutated):"
b=$(run "$PWD/$SRC"); echo "  reds: ${b:-NONE}"
echo

mut() { # $1=name  $2=python-mutation
  cp "$SRC" "m.tmp"
  python3 - "$2" <<'PY'
import sys,re
p='m.tmp'; s=open(p).read()
exec(sys.argv[1])
open(p,'w').write(s)
PY
  bash -n m.tmp 2>/dev/null || { echo "  !! mutant does not parse"; return; }
  r=$(run "$PWD/m.tmp")
  printf '  %-46s -> reds: %s\n' "$1" "${r:-NONE  ❌❌ FIXTURE IS VACUOUS}"
}

echo "MUTANTS (each should turn its guard-arm RED):"
mut "M1 symlink meter: read the blob, ignore the mode" \
  "s=s.replace('''    mode=\$(git ls-tree \"\$oid\" -- \"\$path\" 2>/dev/null | awk '{print \$1}')''','''    mode=100644''',1)"

mut "M2 fail-OPEN: unguard the empty-array expansion" \
  "s=s.replace('queue=(\${next[@]+\"\${next[@]}\"})','queue=(\"\${next[@]}\")',1)"

mut "M3 identity guard keys on HEAD only" \
  "s=s.replace('for ref in HEAD refs/remotes/origin/main; do','for ref in HEAD; do',1)"

mut "M4 dangling import: weigh 0 (no deletion split)" \
  "s=s.replace('*) status=import_dangling ;;','*) : ;;',1)"

mut "M5 rung order: tracking ref before first-push" \
  "s=s.replace('if [ \"\$remote_oid\" = \"\$zero\" ]; then','if [ \"\$remote_oid\" = \"\$zero\" ] && false; then',1)"

mut "M6 no rung-0 (already-published escape)" \
  "s=s.replace('if [ -n \"\$canon_bytes\" ] && [ \"\$cur\" -eq \"\$canon_bytes\" ]','if false && [ \"\$cur\" -eq \"\$canon_bytes\" ]',1)"

echo
echo "INSTALLER MUTANT (separate — mutates the installer, not the hook):"
cp install-hooks-v13.sh i.tmp
python3 - <<'PY'
p='i.tmp'; s=open(p).read()
# the round-10 installer: install into $(git rev-parse --git-path hooks), which FOLLOWS a global core.hooksPath
s=s.replace('if cfg=$(git config --get core.hooksPath 2>/dev/null) && [ -n "$cfg" ]; then',
            'if false; then')
s=s.replace('DEST="$(git rev-parse --git-common-dir)/hooks"',
            'DEST="$(git rev-parse --git-path hooks)"')
open(p,'w').write(s)
PY
sed 's|INST=/Users/markmark/.claude/jobs/2e729592/tmp/install-hooks-v13.sh|INST=/Users/markmark/.claude/jobs/2e729592/tmp/i.tmp|' suite-v13.sh > s.tmp
r=$(bash s.tmp 2>&1 | grep -E '^❌' | sed 's/❌ *//;s/ *want=.*//' | tr '\n' ';')
printf '  %-46s -> reds: %s\n' "MI round-10 installer (--git-path hooks)" "${r:-NONE  ❌❌ VACUOUS}"
rm -f m.tmp i.tmp s.tmp
