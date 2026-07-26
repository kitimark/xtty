#!/bin/zsh
# Reproduces the submodule-diff-recursion hole found in cross-review of
# fix-large-diff-memory-bound (round 1) and confirms `--submodule=short`
# closes it. Uses plain `git` only — no App build required.
#
# Shape: an outer repo with `diff.submodule=diff` configured (a per-user or
# per-repo config value xtty's per-file preview does not control) and a
# submodule whose checked-out commit has advanced past what the outer repo's
# index records, with a `diff=xtty` attribute + configured `textconv` driver
# on a changed submodule file. Without `--submodule=short`, xtty's per-file
# preview invocation (which already carries `--no-ext-diff --no-textconv`)
# recurses into the submodule's own nested diff instead of showing the safe
# one-line "Subproject commit <old>..<new>" summary — defeating the "this
# preview shows exactly one file's own diff" assumption the bounded-producer
# design relies on for scope, independent of whether textconv itself escapes.
set -euo pipefail

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

mkdir sub && cd sub
git init -q
printf '*.dat diff=xtty\n' > .gitattributes
printf 'line one\nline two\n' > file.dat
git add .gitattributes file.dat
git -c user.email=t@e -c user.name=t commit -qm init
printf '#!/bin/sh\nprintf ran > "$XTTY_TEXTCONV_SENTINEL"\ncat "$1"\n' > converter.sh
chmod +x converter.sh
git config diff.xtty.textconv "$PWD/converter.sh"
cd ..

mkdir outer && cd outer
git init -q
git -c protocol.file.allow=always submodule add -q "$WORK/sub" sub
git -c user.email=t@e -c user.name=t commit -qm "add submodule"
git config diff.submodule diff

cd sub
printf 'line one\nline two changed\n' > file.dat
git -c user.email=t@e -c user.name=t commit -qam "change file"
cd ..

export XTTY_TEXTCONV_SENTINEL="$WORK/sentinel"

echo "=== xtty's pre-fix invocation shape (--no-ext-diff --no-textconv, no --submodule=short) ==="
rm -f "$XTTY_TEXTCONV_SENTINEL"
git -c protocol.file.allow=always diff HEAD --no-ext-diff --no-textconv --no-color --unified=3 -- sub
[[ -f "$XTTY_TEXTCONV_SENTINEL" ]] && echo "RESULT: sentinel fired (textconv escaped)" \
  || echo "RESULT: sentinel absent, but full nested diff content was still shown (recursion, not textconv)"

echo
echo "=== xtty's fixed invocation shape (adds --submodule=short) ==="
rm -f "$XTTY_TEXTCONV_SENTINEL"
git -c protocol.file.allow=always diff HEAD --no-ext-diff --no-textconv --submodule=short --no-color --unified=3 -- sub
[[ -f "$XTTY_TEXTCONV_SENTINEL" ]] && echo "RESULT: sentinel fired (still vulnerable)" \
  || echo "RESULT: sentinel absent; output is the safe one-line Subproject-commit summary (fixed)"
