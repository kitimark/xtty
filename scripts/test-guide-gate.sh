#!/bin/bash
# The guide-gate mutation suite. EVERY ARM IS ISOLATED (fresh repo + remote) —
# arms were previously coupled through shared remote state and one early red
# cascaded into spurious downstream reds.
set -u
HOOK="${HOOK:-$(cd "$(dirname "$0")/.." && pwd)/.githooks/pre-push}"
INST="${INST:-$(cd "$(dirname "$0")" && pwd)/install-hooks.sh}"
ROOT=$(mktemp -d "${TMPDIR:-/tmp}/xtty-guide-gate-suite.XXXXXX") || {
  echo "FATAL: cannot create the scratch root — the suite cannot run. (A previous version reported" >&2
  echo "       21 'passes' in a sandbox where mktemp failed. A green suite that never ran is a lie.)" >&2
  exit 2; }
[ -d "$ROOT" ] && [ -w "$ROOT" ] || { echo "FATAL: scratch root not writable: $ROOT" >&2; exit 2; }
command -v git >/dev/null || { echo "FATAL: no git" >&2; exit 2; }
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
newrepo() { # $1 = name -> echoes workdir  (setup failure is FATAL, never a silent pass)
  local d="$ROOT/$1"
  mkdir -p "$d" || { echo "FATAL: mkdir $d failed" >&2; exit 2; }
  git init -q --bare "$d/remote.git" || { echo "FATAL: git init failed in $d" >&2; exit 2; }
  git init -q "$d/work" || { echo "FATAL: git init failed in $d/work" >&2; exit 2; }
  ( cd "$d/work"
    git config user.email t@t; git config user.name t
    git symbolic-ref HEAD refs/heads/main
    git remote add origin ../remote.git )
  echo "$d/work"
}
arm() { # $1=name $2=PASS|REFUSE $3=cmd(run in $W)
  local out rc got mark
  out=$( cd "$W" && eval "$3" 2>&1 ); rc=$?
  # A-15-4 (2026-07-18, Codex-caught): a nonzero exit used to be classified as REFUSE
  # unconditionally -- a missing ref, a rejected remote update, or any other plain git error
  # would false-positive as "the gate refused," proving nothing. Require the gate's OWN
  # refusal marker; a nonzero exit WITHOUT it is an ERROR (a broken fixture, not a gate verdict)
  # and can never match either expectation, so it is loudly ❌ rather than silently counted.
  if [ $rc -eq 0 ]; then
    got=PASS
  elif echo "$out" | grep -q '^guide-gate: REFUSE'; then
    got=REFUSE
  else
    got=ERROR
  fi
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

# 4. upgrade an already-armed clone (a GENUINE prior install of an OLDER version of our own hook,
#    recorded via the installer itself -- not a hand-edited stand-in, which A-C-5's hash-tracking
#    can no longer distinguish from a foreign hand-merge -- must silently upgrade, no staleness).
W=$(newrepo t4); ( cd "$W"; guide 500; git add -A; git commit -qm base ) >/dev/null 2>&1
OLDHOOK="$ROOT/t4-oldhook"
printf '#!/bin/sh\n# xtty-guide-gate v13\necho OLD\nexit 0\n' > "$OLDHOOK"
( cd "$W" && bash "$INST" "$OLDHOOK" ) >/dev/null 2>&1     # a genuine prior install of an "older" version
( cd "$W" && bash "$INST" "$HOOK" ) >/dev/null 2>&1        # upgrade to the CURRENT tracked source
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
echo "════ ROUND-13 ARMS (fail-open lanes) ════"

# 30. unborn HEAD (git checkout --orphan) must not skip the gate
W=$(newrepo X30); ( cd "$W"
  guide 600; git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  git checkout -q -b fat main; guide 1500; git add -A; git commit -qm fat
  git checkout -q --orphan brandnew            # HEAD now names an UNBORN branch
  git rm -rqf . 2>/dev/null || true ) >/dev/null 2>&1
arm "30. unborn HEAD does not skip the gate" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin fat"

# 31. a PUBLISHED dangling import must not LATCH the gate open
W=$(newrepo X31); ( cd "$W"
  guide_regular 500; git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  printf '# CLAUDE.md\n@AGENTS.md\n@typo.md\n' > CLAUDE.md      # a broken import: allowed (warn)
  git add -A; git commit -qm "broken import"
  XTTY_GUIDE_CEILING=$CEIL git push -q origin main                # now it is PUBLISHED at the baseline
  head -c 1600 /dev/zero | tr '\0' 'x' > AGENTS.md               # ...and now GROW past the ceiling
  git add -A; git commit -qm "grow behind the published dangling import" ) >/dev/null 2>&1
arm "31. growth AFTER a published dangling import still refused" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 32. rung 0 must key on the CLOSURE. Canonical (origin/main) is FAT; the branch forks from a
#     THIN baseline and sets its guide to the SAME TOTAL as canonical but DIFFERENT imported bytes.
#     Old rung 0 diffed only CLAUDE.md/AGENTS.md -> "identical to published" -> ALLOW (wrong).
#     The comparator would refuse it: thin baseline (400) < ceiling, tip (1520) > ceiling.
W=$(newrepo X32); ( cd "$W"
  printf '# CLAUDE.md\n@inc.md\n' > CLAUDE.md
  head -c 380 /dev/zero | tr '\0' 'a' > inc.md
  git add -A; git commit -qm thin; THIN=$(git rev-parse HEAD)
  head -c 1500 /dev/zero | tr '\0' 'a' > inc.md
  git add -A; git commit -qm "canonical is FAT"; git push -q origin main
  bash "$INST" "$HOOK"
  git checkout -q -b side "$THIN"                     # baseline = the THIN commit
  head -c 1500 /dev/zero | tr '\0' 'b' > inc.md      # same TOTAL as canonical, different BYTES
  git add -A; git commit -qm "same total as published, different content" ) >/dev/null 2>&1
arm "32. rung 0 keys on the CLOSURE, not two paths" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin side"


echo
echo "════ ROUND-13 ARMS (fable — incl. 3 of my own fixtures it proved VACUOUS) ════"

# 33. SHARP fence/span: the tokens now point at a REAL, HEAVY committed file.
#     correct parser: not imports => 520 B => PASS.  fence/span-blind parser: weighs 5000 B => REFUSE.
#     (arm 29 could not distinguish these — its tokens named files that did not exist.)
W=$(newrepo Y33); ( cd "$W"
  head -c 5000 /dev/zero | tr '\0' 'B' > big.md          # real, heavy, and NOT an import
  head -c 500  /dev/zero | tr '\0' 'x' > AGENTS.md
  { printf '# CLAUDE.md\n@AGENTS.md\n\n'
    printf 'The `@big.md` span and the block below are NOT imports.\n\n'
    printf '```sh\n@big.md\n```\n'; } > CLAUDE.md
  git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  echo tweak >> AGENTS.md; git add -A; git commit -qm tweak ) >/dev/null 2>&1
arm "33. SHARP fence/span: heavy file behind them is NOT weighed" PASS \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 34. containing-file-relative import resolution — the round-12 D-5 fix was NEVER fixtured
#     (every other fixture's imports live at the repo root, so a root-relative parser passes).
W=$(newrepo Y34); ( cd "$W"
  mkdir -p docs
  printf '# CLAUDE.md\n@docs/a.md\n' > CLAUDE.md
  printf '@b.md\n' > docs/a.md                            # must resolve to docs/b.md, NOT ./b.md
  head -c 200 /dev/zero | tr '\0' 'x' > docs/b.md
  git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  head -c 1600 /dev/zero | tr '\0' 'x' > docs/b.md; git add -A; git commit -qm "grow docs/b.md" ) >/dev/null 2>&1
arm "34. import resolves against its CONTAINING FILE (docs/b.md)" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 35. D-13-2: unscoped .claude/rules/*.md is EAGERLY INJECTED => growth there must be gated
W=$(newrepo Y35); ( cd "$W"
  guide 400; mkdir -p .claude/rules
  printf '# conventions\n' > .claude/rules/conventions.md
  git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  head -c 1600 /dev/zero | tr '\0' 'r' > .claude/rules/conventions.md
  git add -A; git commit -qm "the FAKE DIET: move the bulk into an unscoped rule" ) >/dev/null 2>&1
arm "35. unscoped .claude/rules growth is METERED (fake-diet lane)" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 36. ...but a rule WITH `paths:` frontmatter is read-triggered, NOT eager => must not be metered
W=$(newrepo Y36); ( cd "$W"
  guide 400; mkdir -p .claude/rules
  printf -- '---\npaths:\n  - "**/*.swift"\n---\n# scoped\n' > .claude/rules/swift.md
  git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  { printf -- '---\npaths:\n  - "**/*.swift"\n---\n'; head -c 3000 /dev/zero | tr '\0' 's'; } > .claude/rules/swift.md
  git add -A; git commit -qm "grow a SCOPED rule (not eagerly injected)" ) >/dev/null 2>&1
arm "36. a `paths:`-scoped rule is NOT metered (read-triggered)" PASS \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 37. THE ALARM CHANNEL. A clean ALLOW must never claim "refusing". The old ERR trap printed
#     "INTERNAL ERROR ... refusing rather than failing open" and then allowed the push — 6 times
#     in a fully-green run. Assert on the hook's ACTUAL stderr during an allowed push.
W=$(newrepo Y37); ( cd "$W"
  guide 400; git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  printf '# CLAUDE.md\n@AGENTS.md\n@~/private.md\n' > CLAUDE.md   # the un-pushable import lane
  git add -A; git commit -qm "home import" ) >/dev/null 2>&1
out=$( cd "$W" && XTTY_GUIDE_CEILING=$CEIL git push origin main 2>&1 ); rc=$?
if [ $rc -eq 0 ] && ! echo "$out" | grep -q 'refusing rather than failing open'; then
  echo "✅  37. a clean ALLOW never claims 'refusing' (alarm channel honest)"; pass=$((pass+1))
elif [ $rc -ne 0 ]; then
  echo "❌  37. the clean push was REFUSED"; fail=$((fail+1)); FAILED+=("37")
else
  echo "❌  37. ALLOWED the push while printing 'refusing rather than failing open'"; fail=$((fail+1)); FAILED+=("37")
  echo "$out" | grep 'refusing' | head -1 | sed 's/^/        /'
fi

# 38. a GENUINE internal error must REFUSE (fail-closed, for real this time)
W=$(newrepo Y38); ( cd "$W"
  guide 600; git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  guide 1400; git add -A; git commit -qm regrow ) >/dev/null 2>&1
# corrupt the meter's input: an unreadable object store makes `git cat-file -s` fail mid-run
arm "38. malformed FLOOR refuses (the ceiling/floor parse lane)" REFUSE \
    "XTTY_GUIDE_FLOOR=lots git push origin main"


echo
echo "════ ROUND-14 ARMS (gpt — the metering surface I got wrong) ════"

# 39. a rule whose BODY starts a line with "paths:" is NOT frontmatter => still EAGER => metered.
#     (the old `grep '^paths:'` in the first 20 lines falsely exempted it — a fake-diet lane
#      hiding inside the metering code itself.)
W=$(newrepo Z39); ( cd "$W"
  guide 400; mkdir -p .claude/rules
  printf '# rules\nWe document paths:\npaths: are written like this.\n' > .claude/rules/style.md
  git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  { printf '# rules\nWe document paths:\npaths: are written like this.\n'
    head -c 1600 /dev/zero | tr '\0' 'p'; } > .claude/rules/style.md
  git add -A; git commit -qm "grow a rule whose BODY says paths:" ) >/dev/null 2>&1
arm "39. body-text 'paths:' is NOT frontmatter => still metered" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 40. a rule FILENAME WITH SPACES must not be word-split out of the meter
W=$(newrepo Z40); ( cd "$W"
  guide 400; mkdir -p .claude/rules
  printf '# style\n' > ".claude/rules/code style.md"
  git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  head -c 1600 /dev/zero | tr '\0' 'c' > ".claude/rules/code style.md"
  git add -A; git commit -qm "grow a rule with a SPACE in its filename" ) >/dev/null 2>&1
arm "40. rule filename WITH SPACES is still metered" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 41. a TRACKED CLAUDE.local.md is eagerly loaded ("loads alongside CLAUDE.md, treated the same way")
W=$(newrepo Z41); ( cd "$W"
  guide 400; printf '# local\n' > CLAUDE.local.md
  git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  head -c 1600 /dev/zero | tr '\0' 'l' > CLAUDE.local.md
  git add -A; git commit -qm "grow a tracked CLAUDE.local.md" ) >/dev/null 2>&1
arm "41. tracked CLAUDE.local.md is metered (eager root)" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 42. a DANGLING SYMLINK import at the BASELINE must not latch a permanent FALSE REFUSAL.
#     (baseline EXISTENCE via ls-tree != baseline RESOLVABILITY: the symlink is in the tree but
#      resolves to nothing, so it was read as "was fine, now broken" and refused forever.)
W=$(newrepo Z42); ( cd "$W"
  printf '# CLAUDE.md\n@AGENTS.md\n@broken-link.md\n' > CLAUDE.md
  head -c 400 /dev/zero | tr '\0' 'x' > AGENTS.md
  ln -s nowhere.md broken-link.md                  # a symlink that EXISTS but resolves to nothing
  git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  echo "an unrelated change" >> AGENTS.md; git add -A; git commit -qm "unrelated work" ) >/dev/null 2>&1
arm "42. dangling SYMLINK import at baseline: no false-refusal latch" PASS \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"


echo
echo "════ ROUND-14 ARMS (fable) ════"

# 43. A-14-1: a typo'd ceiling in the user's SHELL PROFILE must not make this gate refuse a
#     STRANGER's repo. The identity guard has to run BEFORE the ceiling parse.
W=$(newrepo Z43); SH2="$ROOT/sharedhooks2"; mkdir -p "$SH2"
install -m755 "$HOOK" "$SH2/pre-push"
V=$(newrepo Z43other)                                   # someone else's project — never stamped
( cd "$V"; guide 300; echo x > f.txt; git add -A; git commit -qm work ) >/dev/null 2>&1
out=$( cd "$V" && XTTY_GUIDE_CEILING=64K git -c core.hooksPath="$SH2" push origin main 2>&1 ); rc=$?
if [ $rc -eq 0 ]; then
  echo "✅  43. typo'd ceiling does NOT refuse a stranger's repo"; pass=$((pass+1))
else
  echo "❌  43. THE GATE REFUSED A STRANGER'S REPO over our own env var"; fail=$((fail+1)); FAILED+=("43")
  echo "$out" | grep -i 'guide-gate' | head -1 | sed 's/^/        /'
fi

# 44. A-14-3: a guide that lives ONLY in .claude/CLAUDE.md (no root CLAUDE.md) must be METERED.
#     v18 returned "root_missing" regardless of the queue => never metered, and it printed
#     "no guide => allow" over an eager guide many times the ceiling.
W=$(newrepo Z44); ( cd "$W"
  mkdir -p .claude; printf '# project\n' > .claude/CLAUDE.md   # NO root CLAUDE.md at all
  echo code > src.txt; git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  head -c 1600 /dev/zero | tr '\0' 'C' > .claude/CLAUDE.md
  git add -A; git commit -qm "grow a .claude-only guide" ) >/dev/null 2>&1
arm "44. a .claude/CLAUDE.md-ONLY guide is metered" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 45. ...and deleting the ROOT while .claude/ roots remain is still a root deletion
W=$(newrepo Z45); ( cd "$W"
  guide 3000; mkdir -p .claude; printf '# extra\n' > .claude/CLAUDE.md
  git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  git rm -q AGENTS.md CLAUDE.md; git commit -qm "drop the root guide" ) >/dev/null 2>&1
arm "45. root guide deleted while .claude/ roots remain => REFUSE" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"


echo
echo "════ ROUND-15 ARMS (Codex, against the CODE — 2026-07-18) ════"

# 46. A-15-1: a STALE local tracking ref must NOT be trusted as the baseline when the
#     advertised remote_oid is unresolvable locally. The remote diets 1500->600; a clone that
#     never fetched the diet still believes the remote is 1500 and force-pushes 1400 (real
#     regrowth against the TRUE 600 B remote) -- it must be REFUSED, not allowed via the stale ref.
W=$(newrepo AA46); ( cd "$W"
  guide 1500; git add -A; git commit -qm "fat era"; git push -q origin main ) >/dev/null 2>&1
CL="$ROOT/AA46/stale-clone"; git clone -q "$ROOT/AA46/remote.git" "$CL" 2>/dev/null
( cd "$CL"; git config user.email t@t; git config user.name t
  git checkout -q -B main origin/main
  bash "$INST" "$HOOK" ) >/dev/null 2>&1   # ARM THE STALE CLONE ITSELF -- it's the one that pushes
( cd "$W"; guide 600; git add -A; git commit -qm "THE DIET"; XTTY_GUIDE_CEILING=$CEIL git push -q origin main ) >/dev/null 2>&1
( cd "$CL"; guide 1400; git add -A; git commit -qm "stale clone regrows against its remembered fat baseline" ) >/dev/null 2>&1
W="$CL"
arm "46. stale tracking ref NOT trusted as baseline (remote dieted, clone unaware)" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push --force origin main"

# 47. A-15-2: root deletion must not be MASKED when another eager root's import is ALSO
#     dangling (introduced in the SAME commit that deletes the root). The surviving root
#     stays >= FLOOR so the collapse check alone would miss it too -- only an unconditional
#     root_gone => root_deleted promotion catches this.
W=$(newrepo BB47); ( cd "$W"
  guide 500
  mkdir -p .claude; head -c 2500 /dev/zero | tr '\0' 'e' > .claude/CLAUDE.md   # 2nd eager root, LARGE (>= FLOOR), clean
  git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  git rm -q AGENTS.md CLAUDE.md
  { head -c 2500 /dev/zero | tr '\0' 'e'; printf '\n@nowhere.md\n'; } > .claude/CLAUDE.md   # large 2nd root gains a dangling import in the SAME commit
  git add -A; git commit -qm "drop the root guide behind a large, newly-dangling 2nd root" ) >/dev/null 2>&1
arm "47. root deletion not masked by another root's newly-dangling import" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"


echo
echo "════ ROUND-15.1 ARMS (Codex, stop-gate review — 2026-07-18) ════"

# 48. A-15-2b: root deletion must not be masked when the BASELINE ITSELF already had a
#     PUBLISHED, pre-existing dangling import in another eager root (not newly introduced at
#     the tip, unlike arm 47) -- bas_status becomes import_dangling too, so the old
#     "[bas_status=ok]" guard masked this even after A-15-2's tip-side fix. Surviving root
#     stays >= FLOOR unchanged across both commits.
W=$(newrepo EE48); ( cd "$W"
  guide 500
  mkdir -p .claude
  { head -c 2500 /dev/zero | tr '\0' 'e'; printf '\n@nowhere.md\n'; } > .claude/CLAUDE.md   # dangling import PUBLISHED at baseline
  git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  git rm -q AGENTS.md CLAUDE.md
  git commit -qm "drop the root guide behind an ALREADY-dangling 2nd root" ) >/dev/null 2>&1
arm "48. root deletion not masked by a PRE-EXISTING dangling import at baseline" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 49. A-15-1b: rung-0's "identical to published canonical" exemption must not trust a STALE
#     canonical digest match from a DIFFERENT commit to authorize real regrowth past the
#     ceiling. Canonical (main) is fat and published; a SEPARATE thin-baselined ref is grown to
#     CONTENT-MATCH that fat canonical via its OWN, different commit -- not a real repoint, not
#     zero new objects. Must still be refused (falls through to the ordinary comparator).
W=$(newrepo FF49); ( cd "$W"
  guide 1500; git add -A; git commit -qm "fat era"; git push -q origin main
  bash "$INST" "$HOOK"
  git checkout -q -b thinref
  guide 400; git add -A; git commit -qm "thin baseline"; XTTY_GUIDE_CEILING=$CEIL git push -q origin thinref
  guide 1500; git add -A; git commit -qm "grow thinref to CONTENT-MATCH fat canonical, different commit" ) >/dev/null 2>&1
arm "49. rung-0 content match via a DIFFERENT commit, over ceiling => REFUSE" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin thinref"

# 50. ...but a REAL zero-transfer repoint (same commit object as canonical, not just matching
#     content) must still get the rung-0 fast path even while canonical is over ceiling --
#     A-15-1b must not regress arm 14's original legitimate case.
W=$(newrepo GG50); ( cd "$W"
  guide 400;  git add -A; git commit -qm "thin era"; THIN=$(git rev-parse HEAD)
  git branch old "$THIN"; git push -q origin old
  guide 1500; git add -A; git commit -qm "main is FAT (red window)"
  git push -q origin main
  bash "$INST" "$HOOK" ) >/dev/null 2>&1
arm "50. rung-0 STILL fires for a real same-commit repoint (0 new objs)" PASS \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main:old"

echo
echo "════ CROSS-REVIEW ARMS (Codex + inline Opus, /xtty:cross-review round 1 — 2026-07-18) ════"

# 51. A-C-3: a rule with UNCLOSED frontmatter (`paths:` opened but never closed with a second
#     `---`) is NOT exempted -- must still be METERED. An unmetered fake-diet lane hiding INSIDE
#     what looks like real frontmatter, worse than arm 39's body-text-paths bug.
W=$(newrepo Y51); ( cd "$W"
  guide 400; mkdir -p .claude/rules
  printf -- '---\npaths:\n  - "**/*.ts"\n' > .claude/rules/broken.md    # no closing ---
  git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  head -c 1600 /dev/zero | tr '\0' 'p' >> .claude/rules/broken.md
  git add -A; git commit -qm "grow behind UNCLOSED frontmatter" ) >/dev/null 2>&1
arm "51. UNCLOSED frontmatter (no 2nd ---) does NOT exempt a rule" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 52. ...regression guard: a PROPERLY closed frontmatter block must still be exempt (arm 36
#     already covers this shape; re-asserted here alongside 51 so the two can't silently trade
#     places -- a 51-fix that over-refuses ANY paths: line would flip this arm red).
W=$(newrepo Y52); ( cd "$W"
  guide 400; mkdir -p .claude/rules
  printf -- '---\npaths:\n  - "**/*.ts"\n---\n# scoped\n' > .claude/rules/ok.md
  git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  { printf -- '---\npaths:\n  - "**/*.ts"\n---\n'; head -c 3000 /dev/zero | tr '\0' 's'; } > .claude/rules/ok.md
  git add -A; git commit -qm "grow a PROPERLY closed scoped rule" ) >/dev/null 2>&1
arm "52. PROPERLY closed frontmatter is still exempt (no regression)" PASS \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 53. A-C-2: a DIRECTORY-mode symlink under .claude/rules/ (a documented, sanctioned Claude Code
#     pattern -- "Symlinks are resolved and loaded normally", code.claude.com/docs/en/memory) is
#     invisible to `git ls-tree -r` (it can never see through a symlink to a directory's contents)
#     -- must REFUSE outright rather than silently weigh real content behind it as zero.
W=$(newrepo Z53); ( cd "$W"
  bash "$INST" "$HOOK"
  guide 400
  mkdir -p external-rules .claude/rules
  head -c 5000 /dev/zero | tr '\0' 'e' > external-rules/big.md
  ln -s ../../external-rules .claude/rules/shared
  git add -A; git commit -qm "a directory symlink under .claude/rules, per the docs' own example" ) >/dev/null 2>&1
arm "53. DIRECTORY symlink under .claude/rules/ => REFUSE (meter can't see behind it)" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 54. A-C-2b: an @import whose path traverses an INTERMEDIATE symlinked directory is unresolvable
#     via git's tree object model (confirmed empirically: `git ls-tree <oid> -- linkdir/file.md`
#     returns nothing even though the checked-out filesystem resolves it fine) -- must REFUSE, not
#     silently treat it as an ordinary "never existed" dangling import (weighed 0, warn-only).
W=$(newrepo Z54); ( cd "$W"
  bash "$INST" "$HOOK"
  head -c 400 /dev/zero | tr '\0' 'x' > AGENTS.md
  mkdir -p realdir
  head -c 5000 /dev/zero | tr '\0' 'e' > realdir/big.md
  ln -s realdir linkdir
  printf '# CLAUDE.md\n@AGENTS.md\n@linkdir/big.md\n' > CLAUDE.md
  git add -A; git commit -qm "an @import through an intermediate symlinked directory" ) >/dev/null 2>&1
arm "54. @import THROUGH a symlinked directory => REFUSE (not a benign dangling import)" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 55. A-C-1: a DANGLING import whose PATH CONTAINS A SPACE, in the SAME commit that deletes the
#     guide root, must not corrupt resolve_guide's field-parsing and mask the deletion. `read`'s
#     word-splitting on an embedded space in the (formerly middle) `dangling` field used to shift
#     `root_gone` into a malformed two-word string that could never equal "yes" -- silently
#     defeating the root-deletion check. (`dangling` is now the LAST field -- A-C-1's fix.)
#     Mirrors arm 47's shape (a large SURVIVING 2nd root, kept >= FLOOR on both sides) deliberately
#     -- the mutation matrix caught that an earlier draft using a SMALL surviving root let the
#     unrelated VAPORIZE-FLOOR check also refuse the same push, masking whether root_gone parsing
#     specifically was ever exercised (the mutant went uncaught by this arm as a result).
W=$(newrepo Z55); ( cd "$W"
  guide 500
  mkdir -p .claude; head -c 2500 /dev/zero | tr '\0' 'e' > .claude/CLAUDE.md   # 2nd eager root, LARGE (>= FLOOR), stays large
  git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  git rm -q AGENTS.md CLAUDE.md
  { head -c 2500 /dev/zero | tr '\0' 'e'; printf '\n@nowhere here.md\n'; } > .claude/CLAUDE.md   # SPACED dangling import, same commit as the root deletion
  git add -A; git commit -qm "drop the root guide behind a SPACED dangling import (field-shift escape)" ) >/dev/null 2>&1
arm "55. root deletion not masked by a SPACED dangling import (field-shift escape)" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 56. A-C-5: a hand-merged FOREIGN hook (containing our sentinel, per the recovery instructions'
#     own "merge the logic from $SRC by hand" step) must NOT be silently clobbered by a ROUTINE
#     reinstall (`make build`/`test`/etc. via the order-only `hooks` prerequisite -- not just an
#     explicit `make hooks`, which the OLD warning only cautioned against by name).
W=$(newrepo HH56); ( cd "$W"
  mkdir -p .git/hooks
  printf '#!/bin/bash\necho "irreplaceable foreign logic"\nexit 0\n' > .git/hooks/pre-push
  chmod +x .git/hooks/pre-push
  bash "$INST" "$HOOK" >/dev/null 2>&1          # step 1: foreign, no sentinel yet -> refuses, untouched
  { cat .git/hooks/pre-push; echo; cat "$HOOK"; } > .git/hooks/pre-push.new
  mv .git/hooks/pre-push.new .git/hooks/pre-push; chmod +x .git/hooks/pre-push
  git config xtty.guide-gate true               # a user who stamped WITHOUT recording the hash
  bash "$INST" "$HOOK" >/dev/null 2>&1 ) >/dev/null 2>&1   # step 2: a ROUTINE reinstall (the risk)
if grep -q "irreplaceable foreign logic" "$W/.git/hooks/pre-push" 2>/dev/null; then
  echo "✅  56. hand-merged foreign hook survives a routine reinstall"; pass=$((pass+1))
else
  echo "❌  56. hand-merged foreign hook was CLOBBERED by a routine reinstall"; fail=$((fail+1)); FAILED+=("56")
fi

# 57. A-C-6: a WORKTREE-scoped core.hooksPath override must be diagnosed as worktree-scoped, not
#     misreported as "global" (whose suggested fix, a LOCAL-scope write, is silently outranked by
#     the worktree-scoped value and provably does not take effect).
W=$(newrepo II57)
( cd "$W"; guide 500; git add -A; git commit -qm base
  git config extensions.worktreeConfig true
  git worktree add -q -b II57wt "$ROOT/II57/wt" >/dev/null 2>&1
  cd "$ROOT/II57/wt"
  git config --worktree core.hooksPath "$ROOT/II57/wt-only-hooks" ) >/dev/null 2>&1
out=$( cd "$ROOT/II57/wt" && bash "$INST" "$HOOK" 2>&1 )
if echo "$out" | grep -q 'set for THIS WORKTREE'; then
  echo "✅  57. worktree-scoped core.hooksPath correctly diagnosed (not misreported as global)"; pass=$((pass+1))
else
  echo "❌  57. worktree-scoped core.hooksPath MISDIAGNOSED"; fail=$((fail+1)); FAILED+=("57")
  echo "$out" | head -3 | sed 's/^/        /'
fi

# 58. ...and a rule whose BODY has BOTH a `paths:` line and a LATER stray `---` line, but never
#     opens with `---` on line 1 (no REAL frontmatter block at all), must not be exempted either
#     -- the OPENING delimiter is a separate requirement from the CLOSING one (51 tests closing;
#     this tests opening). Un-vacuates the pre-existing "frontmatter check = grep ^paths:"
#     mutant, which A-C-3's closing-delimiter fix had incidentally superseded against arm 39's own
#     (no-stray-"---") content -- the mutation matrix caught this itself (0 arms, NONE <-- VACUOUS).
W=$(newrepo Y58); ( cd "$W"
  guide 400; mkdir -p .claude/rules
  printf 'Some notes.\npaths: are documented like this.\n---\nmore notes\n' > .claude/rules/style.md
  git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  head -c 1600 /dev/zero | tr '\0' 's' >> .claude/rules/style.md
  git add -A; git commit -qm "grow a rule with body-text paths: AND a later stray --- (no real opening)" ) >/dev/null 2>&1
arm "58. body-text paths:+stray --- (no OPENING ---) does NOT exempt" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

echo
echo "════ CROSS-REVIEW ARMS (Codex + inline Opus, /xtty:cross-review round 2 — 2026-07-18) ════"

# 59. A-C-seen: resolve_guide's `seen` dedup was a SUBSTRING match on a space-joined string, not
#     exact membership -- a queued path whose TAIL exactly equals a later, genuinely DISTINCT path
#     (bounded by spaces) got silently treated as already-processed, and its growth was never
#     added to the total. A pre-existing bug (predates this session's fixes), found independently
#     by the inline soundness pass while hunting beyond its brief.
W=$(newrepo HH59); ( cd "$W"
  bash "$INST" "$HOOK"
  guide 400
  mkdir -p .claude/rules
  printf '# ok\n' > ".claude/rules/AAA bar.md"
  printf '# ok\n' > bar.md
  printf '# CLAUDE.md\n@AGENTS.md\n@bar.md\n' > CLAUDE.md
  git add -A; git commit -qm base; git push -q origin main
  head -c 5000 /dev/zero | tr '\0' 'z' > bar.md
  git add -A; git commit -qm "grow a DISTINCT bar.md whose name tail-collides with another queued path" ) >/dev/null 2>&1
arm "59. seen-dedup does not false-positive on a tail-suffix collision" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 60. A-C-2c: is_dir_symlink resolved exactly ONE symlink hop -- a symlink pointing at ANOTHER
#     symlink that in turn points at a directory fell through undetected, WORSE than the original
#     bug (not even flagged, totally silent). Loop like resolve_entry does instead.
W=$(newrepo II60); ( cd "$W"
  bash "$INST" "$HOOK"
  guide 400
  mkdir -p external-rules
  head -c 5000 /dev/zero | tr '\0' 'e' > external-rules/big.md
  ln -s external-rules intermediate-link
  mkdir -p .claude/rules
  ln -s ../../intermediate-link .claude/rules/shared
  git add -A; git commit -qm "a 2-hop directory symlink chain under .claude/rules" ) >/dev/null 2>&1
arm "60. a 2-HOP directory symlink chain is still detected (not just 1 hop)" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 61. A-C-2d: an EMPTY queue used to hardcode status=root_missing UNCONDITIONALLY, discarding an
#     already-detected unresolved_symlink -- a directory symlink as the ONLY thing under
#     .claude/rules (no CLAUDE.md at all) was waved through as "no guide", worse than an ordinary
#     refuse, since real content behind the symlink genuinely exists and is injected.
W=$(newrepo JJ61); ( cd "$W"
  bash "$INST" "$HOOK"
  mkdir -p external-rules .claude/rules
  head -c 5000 /dev/zero | tr '\0' 'e' > external-rules/big.md
  ln -s ../../external-rules .claude/rules/shared
  echo code > src.txt
  git add -A; git commit -qm "no CLAUDE.md at all -- ONLY a directory symlink under .claude/rules" ) >/dev/null 2>&1
arm "61. directory symlink as the SOLE eager root is still refused (not 'no guide')" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 62. A-C-comma: a git filename may legally contain a COMMA -- the comma-joined dangling-path list
#     mis-split a path like "a,b.md" back into two fragments that never resolve as themselves, so
#     the per-path vaporize-deletion check silently missed a real deletion. Switched the internal
#     delimiter to the ASCII Unit Separator (a byte no real filename plausibly contains).
W=$(newrepo KK62); ( cd "$W"
  guide 2500
  mkdir -p .claude/docs
  { head -c 2500 /dev/zero | tr '\0' 'e'; printf '\n@docs/a,b.md\n'; } > .claude/CLAUDE.md
  printf '# real content\n' > ".claude/docs/a,b.md"
  git add -A; git commit -qm base; git push -q origin main
  bash "$INST" "$HOOK"
  git rm -q ".claude/docs/a,b.md"
  git commit -qm "delete a COMMA-named import that resolved at baseline" ) >/dev/null 2>&1
arm "62. deleting a COMMA-named resolved import is not masked by mis-splitting" REFUSE \
    "XTTY_GUIDE_CEILING=$CEIL git push origin main"

# 63. A-C-5b: the installer's OWN printed recovery instructions must never tell the user to run a
#     command that causes the NEXT routine reinstall to destroy what they just preserved (verified
#     end-to-end in round 2: following the round-1 instructions literally destroyed the merge on
#     the very next call). Assert BOTH that the printed text never mentions the self-defeating
#     config key, and that a hand-merged hook survives repeated routine reinstalls.
W=$(newrepo LL63); ( cd "$W"
  mkdir -p .git/hooks
  printf '#!/bin/bash\necho "irreplaceable foreign logic"\nexit 0\n' > .git/hooks/pre-push
  chmod +x .git/hooks/pre-push
  bash "$INST" "$HOOK" >/dev/null 2>&1
  { cat .git/hooks/pre-push; echo; cat "$HOOK"; } > .git/hooks/pre-push.new
  mv .git/hooks/pre-push.new .git/hooks/pre-push; chmod +x .git/hooks/pre-push ) >/dev/null 2>&1
out=$( cd "$W" && bash "$INST" "$HOOK" 2>&1 )
( cd "$W" && git config xtty.guide-gate true
  bash "$INST" "$HOOK" >/dev/null 2>&1
  bash "$INST" "$HOOK" >/dev/null 2>&1
  bash "$INST" "$HOOK" >/dev/null 2>&1 )
if echo "$out" | grep -q 'guide-gate-hook-sha'; then
  echo "❌  63. printed recovery text still tells the user to self-defeat (guide-gate-hook-sha)"; fail=$((fail+1)); FAILED+=("63")
elif ! grep -q "irreplaceable foreign logic" "$W/.git/hooks/pre-push" 2>/dev/null; then
  echo "❌  63. hand-merged hook destroyed after repeated routine reinstalls"; fail=$((fail+1)); FAILED+=("63")
else
  echo "✅  63. recovery text is safe AND the merge survives repeated routine reinstalls"; pass=$((pass+1))
fi

echo
echo "════ $pass passed, $fail failed ════"
[ $fail -gt 0 ] && printf 'FAILED: %s\n' "${FAILED[*]}"
echo "ROOT=$ROOT"
exit $fail
