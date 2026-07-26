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
# design relies on for scope, AND (round 2 correction below) letting the
# configured textconv driver execute despite the outer `--no-textconv`.
#
# Round-2 correction (cross-review, both Codex and Fable independently found
# this): round 1's fixture configured `diff.xtty.textconv` in the ORIGIN repo
# before `git submodule add` cloned it — `git clone` never copies local repo
# config, only tracked files (`.gitattributes` travels; `.git/config` does
# not) — so the recursed nested diff ran in a checkout with the `diff=xtty`
# attribute but no configured driver, making the sentinel's absence provable
# but meaningless. This corrected version configures the driver in the
# CHECKOUT (`outer/sub`, post-clone) as well, and asserts both the recursion
# shape and the sentinel outcome instead of printing for human eyeballing.
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
# The round-2 fix: `submodule add` clones sub's tracked content (including
# .gitattributes) but not its local git config, so the checkout has the
# `diff=xtty` attribute pointing at a driver that isn't configured *here*
# unless we configure it again, in the checkout.
git -C sub config diff.xtty.textconv "$WORK/sub/converter.sh"

cd sub
printf 'line one\nline two changed\n' > file.dat
git -c user.email=t@e -c user.name=t commit -qam "change file"
cd ..

export XTTY_TEXTCONV_SENTINEL="$WORK/sentinel"
fail=0

echo "=== xtty's pre-fix invocation shape (--no-ext-diff --no-textconv, no --submodule=short) ==="
rm -f "$XTTY_TEXTCONV_SENTINEL"
vuln_output="$(git -c protocol.file.allow=always diff HEAD --no-ext-diff --no-textconv --no-color --unified=3 -- sub)"
print -r -- "$vuln_output"
if [[ "$vuln_output" != *"+line two changed"* ]]; then
  echo "ASSERTION FAILED: expected the vulnerable shape to recurse into the submodule's nested content diff (missing '+line two changed')" >&2
  fail=1
fi
if [[ ! -f "$XTTY_TEXTCONV_SENTINEL" ]]; then
  echo "ASSERTION FAILED: expected the configured textconv driver to execute (escaping the outer --no-textconv) during recursion — sentinel is absent" >&2
  fail=1
else
  echo "RESULT: recursion confirmed (nested content shown) AND textconv escaped (sentinel fired)"
fi

echo
echo "=== xtty's fixed invocation shape (adds --submodule=short) ==="
rm -f "$XTTY_TEXTCONV_SENTINEL"
fixed_output="$(git -c protocol.file.allow=always diff HEAD --no-ext-diff --no-textconv --submodule=short --no-color --unified=3 -- sub)"
print -r -- "$fixed_output"
if [[ "$fixed_output" == *"+line two changed"* ]]; then
  echo "ASSERTION FAILED: --submodule=short did not prevent recursion into nested content" >&2
  fail=1
fi
if [[ "$fixed_output" != *"Subproject commit"* ]]; then
  echo "ASSERTION FAILED: expected the fixed shape's output to contain the safe one-line 'Subproject commit' summary" >&2
  fail=1
fi
if [[ -f "$XTTY_TEXTCONV_SENTINEL" ]]; then
  echo "ASSERTION FAILED: the configured textconv driver executed even with --submodule=short — the fix did not close the escape" >&2
  fail=1
else
  echo "RESULT: recursion closed (safe one-line summary only) AND textconv did not execute (sentinel absent)"
fi

exit "$fail"
