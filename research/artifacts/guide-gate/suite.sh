#!/bin/bash
# The guide-gate mutation suite. EVERY ARM IS ISOLATED (fresh repo + remote) —
# arms were previously coupled through shared remote state and one early red
# cascaded into spurious downstream reds.
set -u
HOOK="${HOOK:-/Users/markmark/.claude/jobs/2e729592/tmp/pre-push-v15}"
INST=/Users/markmark/.claude/jobs/2e729592/tmp/install-hooks-v15.sh
ROOT=$(mktemp -d /Users/markmark/.claude/jobs/2e729592/tmp/suite.XXXX)
CEIL=1000
pass=0; fail=0; FAILED=()

guide() { # $1=bytes ; symlink shape (like main)
  head -c "$1" /dev/zero | tr '\0' 'x' > AGENTS.md
  ln -sf AGENTS.md CLAUDE.md
}
guide_regular() { # regular-file root + @import (the shape 3 xtty refs carry)
  head -c "$1" /dev/zero | tr '\0' 'x' > AGENTS.md
  printf '# CLAUDE.md\n@AGENTS.md\n' > CLAUDE.md
}
newrepo() { # $1 = name -> echoes workdir
  local d="$ROOT/$1"
  mkdir -p "$d"; git init -q --bare "$d/remote.git"; git init -q "$d/work"
  ( cd "$d/work"
    git config user.email t@t; git config user.name t
    git symbolic-ref HEAD refs/heads/main
    git remote add origin ../remote.git )
  echo "$d/work"
}
arm() { # $1=name $2=PASS|REFUSE $3=cmd(run in $W)
  local out rc got mark
  out=$( cd "$W" && eval "$3" 2>&1 ); rc=$?
  got=PASS; [ $rc -ne 0 ] && got=REFUSE
  if [ "$got" = "$2" ]; then mark="✅"; pass=$((pass+1)); else mark="❌"; fail=$((fail+1)); FAILED+=("$1"); fi
  printf '%s  %-56s want=%-6s got=%s\n' "$mark" "$1" "$2" "$got"
  echo "$out" | grep -E 'guide-gate:|hooks:' | grep -v RECOVERY | grep -v '^guide-gate: -' | head -2 | sed 's/^/        /'
}

echo "════ INSTALLER ════"

# 1. checkout-disarm: the gate must survive checking out a branch that predates it
W=$(newrepo t1); ( cd "$W"
  guide 500; git add -A; git commit -qm base; git branch legacy      # legacy has no hook, no matter
  bash "$INST" "$HOOK" >/dev/null 2>&1
  guide 1500; git add -A; git commit -qm "grow the guide"            # over ceiling => must refuse
  git checkout -q legacy ) >/dev/null 2>&1
arm "1. survives checkout of a hookless branch (main push)" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 2. foreign core.hooksPath => installer must WARN + STOP (never leak the gate out)
W=$(newrepo t2); ( cd "$W"; guide 500; git add -A; git commit -qm base
  mkdir -p "$W/../foreign"; git config core.hooksPath "$W/../foreign" ) >/dev/null 2>&1
out=$( cd "$W" && bash "$INST" "$HOOK" 2>&1 )
if [ -e "$W/../foreign/pre-push" ]; then
  echo "❌  2. foreign core.hooksPath: installer LEAKED the gate into it"; fail=$((fail+1)); FAILED+=("2")
else
  echo "✅  2. foreign core.hooksPath: installer refused to write there"; pass=$((pass+1))
  echo "$out" | head -1 | sed 's/^/        /'
fi

# 3. CROSS-REPO HARM: the gate sitting in a SHARED hooks dir must NOT gate a foreign repo
W=$(newrepo t3); SH="$ROOT/sharedhooks"; mkdir -p "$SH"
install -m755 "$HOOK" "$SH/pre-push"
( cd "$W"; guide 5000; git add -A; git commit -qm base ) >/dev/null 2>&1   # xtty-like: has a guide
V=$(newrepo t3other)                          # a DIFFERENT project THAT ALSO HAS AN AGENT GUIDE
( cd "$V"; guide 9000; echo "print('hi')" > main.py; git add -A; git commit -qm work ) >/dev/null 2>&1
out=$( cd "$V" && git -c core.hooksPath="$SH" push origin main 2>&1 ); rc=$?
if [ $rc -eq 0 ]; then
  echo "✅  3. shared hooks dir: unrelated repo NOT gated (identity guard)"; pass=$((pass+1))
else
  echo "❌  3. THE GATE BLOCKED AN UNRELATED REPOSITORY"; fail=$((fail+1)); FAILED+=("3")
  echo "$out" | head -2 | sed 's/^/        /'
fi

# 4. upgrade an already-armed clone (sentinel => own copy => overwrite)
W=$(newrepo t4); ( cd "$W"; guide 500; git add -A; git commit -qm base
  bash "$INST" "$HOOK" ) >/dev/null 2>&1
printf '#!/bin/sh\n# xtty-guide-gate v13\necho OLD\nexit 0\n' > "$W/.git/hooks/pre-push"
( cd "$W" && bash "$INST" "$HOOK" ) >/dev/null 2>&1
if cmp -s "$HOOK" "$W/.git/hooks/pre-push"; then
  echo "✅  4. upgrade in an armed clone: own copy overwritten (no staleness)"; pass=$((pass+1))
else
  echo "❌  4. upgrade in an armed clone: installed copy went STALE"; fail=$((fail+1)); FAILED+=("4")
fi

# 5. a FOREIGN pre-push (no sentinel) must NOT be clobbered
W=$(newrepo t5); ( cd "$W"; guide 500; git add -A; git commit -qm base ) >/dev/null 2>&1
printf '#!/bin/sh\necho "somebody elses hook"\nexit 0\n' > "$W/.git/hooks/pre-push"; chmod +x "$W/.git/hooks/pre-push"
( cd "$W" && bash "$INST" "$HOOK" ) >/dev/null 2>&1
if grep -q "somebody elses hook" "$W/.git/hooks/pre-push"; then
  echo "✅  5. foreign pre-push preserved (warn + stop, no clobber)"; pass=$((pass+1))
else
  echo "❌  5. foreign pre-push was CLOBBERED"; fail=$((fail+1)); FAILED+=("5")
fi

echo
echo "════ THE LADDER (main dieted: guide 600, ceiling $CEIL) ════"

# shared fixture builder: fat history -> diet on main -> armed
mkladder() {
  W=$(newrepo "$1"); ( cd "$W"
    guide 1500; git add -A; git commit -qm "fat era"; FAT=$(git rev-parse HEAD); echo "$FAT" > .fat
    git tag v0.0.1
    git push -q origin main; git push -q origin v0.0.1
    bash "$INST" "$HOOK"
    guide 600; git add -A; git commit -qm "THE DIET"
    XTTY_GUIDE_CEILING=$CEIL git push -q origin main ) >/dev/null 2>&1
  FAT=$(cat "$W/.fat")
}

mkladder L6; ( cd "$W" && git branch spike "$FAT" ) >/dev/null 2>&1
arm "6. first-push a ref pinned at a FAT historical commit" PASS \
    "XTTY_GUIDE_CEILING=$CEIL git push origin spike"

mkladder L7; ( cd "$W" && git tag hotfix "$FAT" ) >/dev/null 2>&1
arm "7. push a TAG at a fat historical commit" PASS \
    "XTTY_GUIDE_CEILING=$CEIL git push origin hotfix"

mkladder L8; ( cd "$W" && git branch spike "$FAT" && XTTY_GUIDE_CEILING=$CEIL git push -q origin spike \
   && git checkout -q spike && guide 1900 && git add -A && git commit -qm grow ) >/dev/null 2>&1
arm "8. GROWTH on that historical ref still refused" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin spike"

mkladder L9; ( cd "$W" && git checkout -q -b feat && git rm -q AGENTS.md CLAUDE.md && git commit -qm "rm guide" ) >/dev/null 2>&1
arm "9. guide DELETED on a feature branch (symlink shape)" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin feat"

# 10. THE VAPORIZE LANE — regular-file root + @import; delete the IMPORT, root survives
W=$(newrepo L10); ( cd "$W"
  guide_regular 800; git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  git rm -q AGENTS.md; git commit -qm "oops: git add -A after an mv" ) >/dev/null 2>&1
arm "10. guide deleted BEHIND a regular-file root (import lane)" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 11. an un-pushable home import must NOT refuse (weigh 0 + warn)
W=$(newrepo L11); ( cd "$W"
  guide 500; git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  printf '# CLAUDE.md\n@AGENTS.md\n@~/private-notes.md\n' > CLAUDE.md; rm -f CLAUDE.md
  printf '# CLAUDE.md\n@AGENTS.md\n@~/private-notes.md\n' > CLAUDE.md
  git add -A; git commit -qm "add a home import" ) >/dev/null 2>&1
arm "11. un-pushable @~/ import: weigh 0, do not refuse" PASS \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 12. refs/notes / unrelated history must pass
mkladder L12; ( cd "$W" && git notes add -m "a note" HEAD ) >/dev/null 2>&1
arm "12. push refs/notes (unrelated history, no guide)" PASS \
    "XTTY_GUIDE_CEILING=$CEIL git push origin refs/notes/commits"

# 13. recreated branch + STALE tracking ref => first-push detected first
mkladder L13; ( cd "$W"
  git branch tmp; XTTY_GUIDE_CEILING=$CEIL git push -q origin tmp        # tracking ref exists
  git push -q origin :tmp                                                # deleted on remote, tracking ref stale
  git branch -D tmp; git branch tmp "$FAT" ) >/dev/null 2>&1             # recreate at the FAT commit
arm "13. recreated branch w/ stale tracking ref (fork-point base)" PASS \
    "XTTY_GUIDE_CEILING=$CEIL git push origin tmp"

# 14. A-4 (fable): during the RED WINDOW, repoint an EXISTING remote ref at main's tip.
#     main's guide is OVER the ceiling; the branch's is UNDER it. The push transmits ZERO
#     new objects (local_oid IS origin/main's tip) — but the naive comparator sees the
#     branch's thin baseline, the fat tip, and refuses. It must PASS.
#     (Built post-diet this arm was VACUOUS — a shrink through the ordinary comparator.
#      The mutation matrix caught that: removing rung 0 turned no arm red.)
W=$(newrepo L14); ( cd "$W"
  guide 400;  git add -A; git commit -qm "thin era"; THIN=$(git rev-parse HEAD)
  git branch old "$THIN"; git push -q origin old            # an existing ref with a THIN guide
  guide 1500; git add -A; git commit -qm "main is FAT (red window)"
  git push -q origin main                                    # seed before arming
  bash "$INST" "$HOOK" ) >/dev/null 2>&1
arm "14. RED window: repoint an existing ref at main (0 new objs)" PASS \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main:old"

# 15. the rung-0 escape must NOT let a force-push rewind main to the fat guide
mkladder L15
arm "15. force-push main BACK to the fat historical guide" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push --force origin ${FAT}:main"

# 16. multi-ref, main NOT first (stdin loop)
mkladder L16; ( cd "$W" && git checkout -q -b zzz && echo x > f && git add -A && git commit -qm x \
  && git checkout -q main && guide 1400 && git add -A && git commit -qm "regrow main" ) >/dev/null 2>&1
arm "16. multi-ref push, main NOT first (guide regrown)" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin zzz main"

# 17. branch deletion
mkladder L17; ( cd "$W" && git branch d1 && XTTY_GUIDE_CEILING=$CEIL git push -q origin d1 ) >/dev/null 2>&1
arm "17. delete a remote branch (all-zero local OID)" PASS \
    "XTTY_GUIDE_CEILING=$CEIL git push origin :d1"

# 18. NEGATIVE: unrelated push during the RED window must not be frozen
W=$(newrepo L18); ( cd "$W"
  guide 1500; git add -A; git commit -qm "fat (RED window)"; git push -q origin main
  bash "$INST" "$HOOK"
  echo code > src.txt; git add -A; git commit -qm "unrelated work" ) >/dev/null 2>&1
arm "18. unrelated push during the RED window (no freeze)" PASS \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 19. main grows the guide
mkladder L19; ( cd "$W" && guide 1400 && git add -A && git commit -qm "regrow" ) >/dev/null 2>&1
arm "19. main REGROWS the guide over the ceiling" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"


echo
echo "════ ROUND-12 ARMS (gpt-5.6-sol, against the CODE) ════"

# 20. UNICODE: the meter must count BYTES, not characters. AGENTS.md is full of ❗✅⚠️.
W=$(newrepo U20); ( cd "$W"
  head -c 900 /dev/zero | tr '\0' 'x' > AGENTS.md; ln -sf AGENTS.md CLAUDE.md
  git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  # same CHARACTER count, far more BYTES: 900 chars -> 2700 bytes (each ❗ is 3 bytes)
  : > AGENTS.md; for i in $(seq 1 900); do printf '\342\235\227' >> AGENTS.md; done
  git add -A; git commit -qm "unicode-only edit" ) >/dev/null 2>&1
echo "        (chars=$(python3 -c "print(len(open('$W/AGENTS.md',encoding='utf-8').read()))")  bytes=$(wc -c < "$W/AGENTS.md" | tr -d ' '))"
arm "20. UNICODE edit: bytes grow past ceiling, chars do not" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 21. an import hop at DEPTH 4 must still be weighed (declared max depth 4)
W=$(newrepo U21); ( cd "$W"
  printf '# root\n@a.md\n' > CLAUDE.md; printf '@b.md\n' > a.md; printf '@c.md\n' > b.md
  printf '@d.md\n' > c.md; head -c 100 /dev/zero | tr '\0' 'x' > d.md
  git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  head -c 1600 /dev/zero | tr '\0' 'x' > d.md; git add -A; git commit -qm "grow the DEEP import" ) >/dev/null 2>&1
arm "21. growth at import HOP 4 is seen (no off-by-one)" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 22. a NEWLY-ADDED broken import is NOT a deletion (must not refuse)
W=$(newrepo U22); ( cd "$W"
  guide_regular 500; git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  printf '# CLAUDE.md\n@AGENTS.md\n@does-not-exist.md\n' > CLAUDE.md
  git add -A; git commit -qm "add a broken import (typo)" ) >/dev/null 2>&1
arm "22. NEWLY-added broken import: warn, do not refuse" PASS \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 23. empty core.hooksPath: git searches the WORKTREE ROOT => installer must not silently no-op
W=$(newrepo U23); ( cd "$W"; guide 500; git add -A; git commit -qm base
  git config core.hooksPath "" ) >/dev/null 2>&1
out=$( cd "$W" && bash "$INST" "$HOOK" 2>&1 )
if echo "$out" | grep -q 'NOT installing'; then
  echo "✅  23. empty core.hooksPath: installer warns + stops"; pass=$((pass+1))
else
  echo "❌  23. empty core.hooksPath: installer silently wrote where git will not look"; fail=$((fail+1)); FAILED+=("23")
fi

# 24. a SECOND remote: the hook must use the remote it is pushing to, not hardcoded origin
W=$(newrepo U24); ( cd "$W"
  guide 1500; git add -A; git commit -qm "fat"; git push -q origin main   # origin/main is FAT
  bash "$INST" "$HOOK"
  git init -q --bare "$ROOT/U24/other.git"; git remote add upstream "$ROOT/U24/other.git"
  ) >/dev/null 2>&1
# vs origin's fat baseline this is "no growth" => allow. vs upstream (EMPTY) there is no
# baseline at all => the absolute ceiling applies => REFUSE. Hardcoding `origin` allows it.
arm "24. 2nd remote uses ITS OWN baseline, not origin's" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push upstream main"


echo
echo "════ ROUND-12 ARMS (fable-5, against the CODE) ════"

# 25. D-1 THE MODE FLIP: symlink -> a 9-byte REGULAR file containing the literal text "AGENTS.md".
#     Not an import. The injected guide really IS 9 bytes — and every path-based deletion rule
#     saw a healthy, resolvable root and called it a legal shrink.
W=$(newrepo V25); ( cd "$W"
  guide 5000; git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  rm CLAUDE.md; printf 'AGENTS.md' > CLAUDE.md          # a REGULAR file, 9 bytes, no @
  git add -A; git commit -qm "symlink materialized by a zip round-trip" ) >/dev/null 2>&1
arm "25. symlink MATERIALIZED to a 9-byte stub (vaporize)" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 26. D-3(a): a malformed ceiling must REFUSE, never allow
W=$(newrepo V26); ( cd "$W"
  guide 600; git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  guide 1400; git add -A; git commit -qm regrow ) >/dev/null 2>&1
arm "26. malformed XTTY_GUIDE_CEILING=64K refuses (fail-closed)" REFUSE \
    "XTTY_GUIDE_CEILING=64K git push origin main"

# 27. D-4: the remote advertised an OID we never fetched => measure, don't blanket-allow
W=$(newrepo V27); ( cd "$W"
  guide 400; git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK" ) >/dev/null 2>&1
# a second clone pushes branch X; we never fetch it, then force-push our own fat X
CL="$ROOT/V27/clone2"; git clone -q "$ROOT/V27/remote.git" "$CL" 2>/dev/null
( cd "$CL"; git config user.email t@t; git config user.name t
  git checkout -q -b X; echo y > y.txt; git add -A; git commit -qm x; git push -q origin X ) >/dev/null 2>&1
( cd "$W"; git checkout -q -b X; guide 1500; git add -A; git commit -qm "fat X" ) >/dev/null 2>&1
arm "27. unfetched advertised OID: measured, not blanket-allowed" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push --force origin X"

# 28. D-5(i): a MID-LINE import (the docs' own example shape) must be followed
W=$(newrepo V28); ( cd "$W"
  printf '# Guide\nSee @AGENTS.md for the project overview.\n' > CLAUDE.md
  head -c 300 /dev/zero | tr '\0' 'x' > AGENTS.md
  git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  head -c 1600 /dev/zero | tr '\0' 'x' > AGENTS.md
  git add -A; git commit -qm "grow behind a MID-LINE import" ) >/dev/null 2>&1
arm "28. MID-LINE import is followed (docs grammar)" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 29. D-5(ii): an @token in PROSE / a fenced block is not an import — must not false-refuse
W=$(newrepo V29); ( cd "$W"
  guide 500; git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  { printf '# CLAUDE.md\n@AGENTS.md\n\n'
    printf 'Paths under @openspec/changes/ are allowlisted, per the gate.\n\n'
    printf '```sh\n@not-an-import.md\n```\n'; } > CLAUDE.md
  git add -A; git commit -qm "prose + fenced @tokens" ) >/dev/null 2>&1
arm "29. @token in prose / fenced code: no false refusal" PASS \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

echo
echo "════ $pass passed, $fail failed ════"
[ $fail -gt 0 ] && printf 'FAILED: %s\n' "${FAILED[*]}"
echo "ROOT=$ROOT"
exit $fail
