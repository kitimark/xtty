# guide-gate — the working prototype behind `bound-the-agents-md-guide`

**Provenance:** 2026-07-13/14, round 12 of the cross-model review loop. These are the *measured*
artifacts, not a sketch: the suite is **19/19 green** and the mutation matrix proves every fix
load-bearing. They exist because **11 rounds of two frontier models reading English missed four
defects that the first execution of the code found in seconds** (see
`../03-analysis/agents-md-structural-best-practices.md` §A5-tricies-quinquies, and G-TARPIT-7).

| file | what it is |
| --- | --- |
| `pre-push` | the gate. Meter = resolve `CLAUDE.md` in the **pushed tree** + follow `@`-imports transitively; refuse growth past the ceiling. **Fails CLOSED.** |
| `install-hooks.sh` | `make hooks`. Installs into the repo's **own git dir** (checkout cannot reach it). Refuses to write into a hooks dir it does not own. |
| `suite.sh` | 19 **isolated** fixtures (fresh repo + remote per arm — they were coupled, and one red cascaded into fake reds). |
| `mutants.sh` | reverts each fix; the arm guarding it must go red. **A fixture that never fails is decoration.** |

    bash suite.sh      # 19/19
    bash mutants.sh    # every mutant dies at the right arm

## The four defects only execution found

1. **The meter read 9 bytes for the whole 81 KB guide.** `git show <oid>:CLAUDE.md` on a **symlink**
   (`120000` — **main's actual shape**) returns the link *target* (`"AGENTS.md"`), not the content.
   The gate could never see growth. Read the tree **mode**; follow the link.
2. **The gate failed OPEN on its own crash.** Under `set -u`, macOS **bash 3.2** errors on
   `"${arr[@]}"` for an **empty array**. The meter died mid-measurement and the hook **still exited 0**
   — installed, armed, sentinel-stamped, and **completely inert**, its own error buried in git's
   transfer output. ⇒ ERR-trap + an integer guard: **any internal error REFUSES.**
3. **The repo-identity guard was self-disabling** — keyed on `HEAD`, so *deleting the guide disabled
   the guard whose job is to refuse guide deletions.* Key it on the **published baseline** too.
4. **A fixture was vacuous** — arm 14 was green and proved nothing (built post-diet it was a *shrink*
   through the ordinary comparator). Only the **mutation matrix** could see that.

## Round 12 — the models reviewed the CODE, and found 11 more (all fixed, all fixtured)

Once the artifact stopped being prose, the findings stopped being arguments. Every one came with a
command. **29/29 green.**

**gpt-5.6-sol (6):** the meter counted **characters, not bytes** (`${#body}` — and this guide is full
of `❗✅⚠️`; a Unicode-only edit grew the blob with **no growth seen**) ⇒ ask git: `git cat-file -s` ·
the declared **4 import hops only followed 3** (the root consumed one) · dangling-import status was
**aggregate, not per-path** (a *newly* broken import was mis-read as a deletion) · the identity guard
matched *"any repo with a guide"*, **not xtty** · an **empty** `core.hooksPath` slipped the installer's
"is it set" check while git searched the worktree root · the hook **hardcoded `origin`**, ignoring the
remote name git passes as `$1`.

**fable-5 (5) — three of them against its own earlier fixes:**
- **D-1 — the symlink fix only handled path DELETION, not a MODE FLIP.** Replace the `120000` link with
  a **9-byte regular file** containing the literal text `AGENTS.md` (a zip round-trip, `rsync` without
  `-l`) and the injected guide really *is* 9 bytes — the root resolves, the meter honestly reports a
  **shrink**, and every path-based deletion rule waves it through. ⇒ **a VAPORIZE FLOOR**, which judges
  the *outcome* rather than the mechanism and **subsumes all three deletion rules**.
- **D-3 — "fails closed" was FALSE.** `XTTY_GUIDE_CEILING=64K` made `[` error and the gate **ALLOW**
  (`is_int` was never applied to the ceiling); and without `set -E` the ERR trap **never fires inside a
  function or subshell**.
- **D-4 — the unfetched-advertised-OID lane allowed with ZERO measurement.**
- **D-5 — the import grammar did not match the docs**: imports appear **anywhere in a line** (the
  official example is mid-sentence), fenced code is skipped, and a relative path resolves against the
  **containing file**. A `^@`-anchored root-relative parser missed the whole mid-line class — 5,048 B of
  injected content read as 48.

Verified against the real repository: the meter now reads **`81012 ok none`** through `main`'s actual
symlink. The version that survived 11 rounds of review would have read **9**.

## Still open (a design decision, not a bug)

The ceiling is a **ratchet**, and its first notch needs the **compressed draft of `AGENTS.md`** —
which no review round can produce. `XTTY_GUIDE_CEILING` is env-overridable so the fixtures can run
at a scaled-down ceiling.

## Round 13 — and the point at which this stopped being the goal

**Both families independently found the SAME defect** (the first time in 13 rounds that happened by
measurement rather than shared framing): **the `import_dangling` LATCH.** Once a guide with one
unresolvable relative `@token` was *published*, `bas_status` and `cur_status` were both non-`ok`, the
"no guide either side ⇒ skip" branch fired, and **every subsequent push was unenforced — ceiling,
ratchet, deletion rule and vaporize floor all bypassed, forever.** Worse: **fixture 22's own end-state
was the latch seed.** Fixed in v16 (skip only when *neither* side has a guide); **arm 31** pins it.

Also fixed in v16: an **unborn HEAD** (`git checkout --orphan`) hit an early `exit 0` and skipped the
gate (arm 30); **rung 0** compared only `CLAUDE.md`/`AGENTS.md`, so equal totals with different
*imported* content passed as "identical to published" — it now hashes the whole resolved closure (arm 32).

### ✅ BOTH ARE NOW FIXED (38/38, one-to-one mutation kills)

- **The ERR trap was LYING — deleted.** `set -E` propagated it into command substitutions, where
  `resolve_entry`'s **expected** `return 1` fired it: the hook printed *"INTERNAL ERROR … refusing
  rather than failing open"* and then **ALLOWED the push** (its `exit 1` killed only the subshell).
  **Six such lines appeared in a fully-GREEN run.** A trap that cannot refuse is worse than no trap —
  it discredits the one channel fail-closed depends on. **Fail-closed is enforced by the explicit
  `is_int` guards, which actually refuse** (arm 38: a malformed ceiling REFUSES; arm 37: a clean
  allow never claims "refusing").
- **`.claude/CLAUDE.md` + unscoped `.claude/rules/*.md` are now METERED.** They are eagerly injected
  (*"rules without `paths` frontmatter are loaded at launch with the same priority as
  `.claude/CLAUDE.md`"*) and were invisible — an unmetered **fake-diet lane**, and the docs' own
  remedy for an oversized guide is *"split it into `.claude/rules/`"*. A `paths:`-scoped rule is
  **read-triggered, not eager** ⇒ correctly **not** metered (arms 35, 36).

### Historical note — the three VACUOUS fixtures fable caught (all now sharp)

Arm 29's fenced/prose `@tokens` named files that **did not exist**, so a fence-blind parser only
warned-and-allowed — the same verdict, proving nothing (**arm 33** now points them at a real 5,000 B
file). **No arm tested containing-file-relative import resolution at all** — round 12's own D-5 fix
was unfixtured (**arm 34**). And the latch mutant survived 29/29 (**arm 31**).

### The old "STILL OPEN" list (kept for the record)

- **The ERR trap CRIES WOLF.** It prints *"INTERNAL ERROR … refusing rather than failing open"* and
  then **ALLOWS the push** — `set -E` propagates the trap into command substitutions, so
  `resolve_entry`'s *expected* `return 1` fires it and the `exit 1` kills only the subshell. **6 such
  lines appear in a fully-green run.** The one channel the fail-closed design depends on is lying on
  routine content. *(Fail-closed is still enforced — by the explicit `is_int` guards, not by the trap.)*
- **`.claude/rules/*.md` (unscoped) and `.claude/CLAUDE.md` are EAGERLY INJECTED but INVISIBLE to the
  meter** — an unmetered "fake diet" lane, and the docs' own recommended remedy for an oversized guide
  is *"split it into `.claude/rules/`"*. Not tracked in this repo today ⇒ a **live mechanism, not an
  observed breakage** (G-GATE-7).
- **Three more of my fixtures were VACUOUS** (fable, by mutation): arm 29's fence/span tokens point at
  files that don't exist, so mis-parsing them yields warn+allow either way; and **no arm tests
  containing-file-relative import resolution at all** — the round-12 D-5 fix is unfixtured.

### ❗ THE REAL FINDING OF ROUND 13 IS ABOUT SCOPE, NOT THE GATE

**`AGENTS.md` is still 81,012 B. The diet — the actual goal — has had zero bytes of work.** The gate is
**downstream** of it: the ceiling is a *ratchet*, and the ratchet's first notch is a number that only a
**compressed draft** can supply. No review round and no fixture can produce that number.

⇒ **The gate is sufficient. The diet is the bottleneck. Stop grooming the mechanism.**

## Round 15 (2026-07-18) — landing found two more, both in the ported logic, both fixed + fixtured

`bound-the-agents-md-guide`'s `/opsx:apply` session ran a Codex review over the freshly-landed tracked
sources (`.githooks/pre-push`, `scripts/install-hooks.sh`, `scripts/test-guide-gate*.sh`) — the first time
this exact code was read by a model *after* it left this scratch directory. It found two more real gaps
that 14 rounds and 45 fixtures never exercised, plus a real hole in the fixture harness itself. All three
fixed; the suite is now **47/47** (45 ported + 2 new) with a **20-mutant** matrix (18 ported + 2 new),
every mutant caught at exactly its own arm — including proof, by running both new fixtures against
*this unmodified prototype file*, that both defects are real here too, not just in the port.

- **A-15-1 — a STALE local tracking ref was trusted as a baseline.** When the advertised remote tip is
  unresolvable locally (a second pusher moved the ref; we never fetched), the old code fell back to
  `git rev-parse refs/remotes/$REMOTE/<branch>` and used it as `base` if it resolved — but that tracking
  ref, by construction, can only be *stale* relative to the real unfetched tip. Measured: a remote diets
  1500→600 B; a clone that never fetched the diet still believes the remote is 1500 and force-pushes
  1400 B — the old code compared 1400 against the stale 1500 "baseline" and **ALLOWED** a real
  over-ceiling regrowth against the true 600 B remote. Fixed by never trusting it: an unresolvable
  advertised tip now always falls through to the absolute-ceiling check, exactly like the true
  no-baseline case. Fixture: arm 46 (`test-guide-gate.sh`); mutant: `ladder: trust a stale local tracking
  ref (A-15-1)`.
- **A-15-2 — root deletion was masked when another eager root's import was ALSO dangling.** The
  `root_gone → root_deleted` promotion required `status = ok` first, so a root deletion sitting alongside
  an unrelated newly-broken `@import` in a *different* eager root (e.g. `.claude/CLAUDE.md`) left the
  reported status at `import_dangling` forever — the caller's root-deletion refusal never fired, and if
  the surviving root's own bytes stayed ≥ `FLOOR`, the collapse check missed it too. Root deletion is the
  more severe finding and must win regardless of what else is dangling. Fixed: `root_gone` now promotes
  unconditionally. Fixture: arm 47; mutant: `deletion: root_deleted needs status=ok again (A-15-2)`.
- **A-15-3 — the mutation matrix itself had no exit-code contract.** `mut()`'s three degradation arms
  (`!! mutation failed`, `!! parse error`, `NONE <-- VACUOUS FIXTURE`) all print-and-return 0, and the
  script's last command was `rm -f _m.tmp` — so `make test-guide-gate`/CI stayed green even if every
  mutant went vacuous. A hook refactor that renamed any mutation anchor would have silently defeated the
  entire matrix with no red anywhere. Fixed: a `bad` counter accumulates every degraded mutant; the
  script now exits non-zero if any exist. (Independently caught by both the Codex pass and a parallel
  Fable 5 review — the same defect, found two different ways.)
- **A-15-4 (fixture-harness hygiene, found while building arm 46) — `arm()` classified ANY nonzero
  `git push` exit as a genuine gate refusal**, including a plain git error (a missing local `main` branch
  in a freshly-checked-out clone, in this case) that never reached the hook's own logic at all. A REFUSE-
  expected arm could pass for entirely the wrong reason, proving nothing. Fixed: `arm()` now requires the
  gate's own `^guide-gate: REFUSE` marker in the captured output; a nonzero exit without it is classified
  `ERROR` and cannot match either expectation.

Two smaller P2 recovery-path gaps (also Codex-caught) were fixed alongside these: `install-hooks.sh`'s
`core.hooksPath` recovery advice didn't account for a globally-inherited value (a local `--unset` is a
silent no-op against it), and its foreign-hook recovery path told the user to merge by hand but never to
set the `xtty.guide-gate` stamp themselves — and warned them, incorrectly, that simply re-running
`make hooks` afterward was safe. Both messages now state the correct, actionable recovery.

**Re-verify by effect (superseded by round 15.1 below — see the current counts there):** `bash suite.sh`
(or `make test-guide-gate`) → `47 passed, 0 failed`; `bash mutants.sh` → 20 rows, none reading
`NONE <-- VACUOUS FIXTURE` or `!!`. To confirm A-15-1/A-15-2 are real defects in *this* file (not
artifacts of the port), point `HOOK` at this directory's own `pre-push` when running the ported suite
from `scripts/test-guide-gate.sh` — arms 46 and 47 both read `got=PASS` (the bug) against this
unmodified prototype, and `got=REFUSE` against the fixed `.githooks/pre-push`.

## Round 15.1 (2026-07-18, same day) — the stop-time review gate caught two round-15 fixes half-closed

The session's Codex **stop-gate review** (a fresh adversarial pass triggered automatically at end-of-turn,
distinct from the on-demand `/codex:review` used for round 15 above) read the just-committed round-15
fixes and found both gate-logic fixes had a narrower blind spot than first closed, plus the round-15 P2
recovery-message fix for `install-hooks.sh` didn't actually terminate — three more real findings, all
fixed the same session. Suite now **50/50** (45 ported + 5 net new), mutation matrix **21/21** (18 ported
+ 3 net new — see the A-15-2 retirement note below), 0 vacuous, 0 failed.

- **A-15-2b — root deletion was STILL masked, on the baseline side this time.** A-15-2 (round 15)
  promoted the aggregate `status` to `root_deleted` when the root vanished, fixing the case where a
  dangling import was introduced *in the same commit* as the deletion. But the caller's refuse check also
  required the **baseline's** aggregate status to be `ok` — so a root deletion sitting behind a
  **pre-existing, already-published** dangling import elsewhere in the closure (present at the baseline
  too, not newly introduced) still slipped through, because `bas_status` was `import_dangling`, never
  `ok`. Fixed by decoupling entirely: `resolve_guide()` now returns a **dedicated 5th field**
  (`root_gone`, yes/no) independent of the aggregate dangling-import status, and the caller checks
  `bas_root_gone=no && cur_root_gone=yes` directly. This **structurally retired A-15-2's own fix and
  mutant** — once the caller stopped reading the aggregate status for this check at all, reverting the
  `status=root_deleted` promotion had no observable effect on any arm (a genuinely vacuous mutant, caught
  by the matrix itself). The dead promotion and its mutant were removed rather than kept as decoration;
  A-15-2's fixture (arm 47) and comment now credit both rounds. Fixture: arm 48 (a pre-existing dangling
  import published at baseline, root deleted in a later commit); mutant: `deletion: root check uses
  aggregate status again (A-15-2/A-15-2b)`.
- **A-15-1b — rung 0 trusted the same kind of stale signal A-15-1 had just closed elsewhere.** A-15-1
  (round 15) stopped trusting a stale local tracking ref as a *baseline* in the unfetched-OID lane. But
  "rung 0" (the already-published-canonical fast path) independently resolves `canonical` from that exact
  same kind of local tracking ref (`refs/remotes/$REMOTE/main`), and only checked **content-digest**
  equality — so a clone that never fetched a diet landed on the real remote main could push a *different*,
  unrelated commit whose guide content happens to content-match the stale fat canonical, and rung 0 would
  wave through real over-ceiling regrowth on a thin-baselined ref. Fixed by requiring EITHER a proven
  zero-transfer repoint (`local_oid` is literally the *same commit object* as `canonical` — true for a
  real `main:<branch>` mirror) OR that the result is itself safely under the ceiling regardless of
  staleness. A content-only match on a **different, over-ceiling** commit no longer gets the fast path.
  Fixture: arm 49 (content-digest match via a different commit, over ceiling, expect REFUSE); arm 50
  re-verifies the original legitimate same-commit-repoint case (arm 14's scenario) still gets the fast
  path unregressed; mutant: `ladder: rung-0 trusts a stale digest match regardless of commit (A-15-1b)`.
- **A-15-7 — the round-15 `core.hooksPath` recovery advice was a reproducible infinite loop.** Round 15
  fixed the global-vs-local scope *detection* but the suggested fix (add a repo-local override pointing
  at the default hooks dir) re-entered the exact same refusal branch on the next run, because the guard
  only checked *whether* `core.hooksPath` was set, never *what it resolved to*. Fixed: resolve the
  configured value the same way git itself does when it actually runs a hook (`git rev-parse --git-path
  hooks`, which follows local-over-global-over-system precedence) and compare it to our own install
  destination — if a local override already neutralizes the foreign/global setting for this repo, proceed
  with installation instead of refusing again. No new fixture (installer-recovery behavior isn't currently
  exercised by the git-push-based suite); verified by reasoning through the resolved-path comparison and
  by the unchanged installer arms (1–5, 23) staying green.

**Re-verify by effect:** `bash suite.sh` (or `make test-guide-gate`) → `50 passed, 0 failed`;
`bash mutants.sh` → `All mutants caught cleanly (0 vacuous, 0 failed)`, exit 0. Confirm arms 48/49 are
real defects in *this* file (not port artifacts) the same way as round 15: point `HOOK` at this
directory's own unmodified `pre-push` — both read `got=PASS` (the bug) there, and `got=REFUSE` against
the fixed `.githooks/pre-push`; arm 50 reads `got=PASS` against both (confirming no regression of the
original legitimate rung-0 case).

## Round C (2026-07-18) — `/xtty:cross-review`, human-launched: 6 real defects, 2 model families

The change's own dogfood: `/xtty:cross-review bound-the-agents-md-guide`, run by the human per the
project's human-attestation gate. Pass A (Opus critic, conformance) returned COHERENT with only stale
doc-count findings (deferred to archive-reconcile). Pass B (Codex `gpt-5.6-sol`, briefed, backgrounded)
and Pass C (an inline Opus soundness pass, given the same brief) each read the code independently and
found **disjoint** defect sets — the point of running two model families. Six real, distinct defects
survived verification (each hand-traced against the actual source, and where the claim depended on
external Claude Code product behavior, checked against the live docs — see the refuted claim below);
zero were accepted on the reviewer's word alone.

- **A-C-1 (Codex) — a dangling import path containing a SPACE corrupted `root_gone` field-parsing.**
  `resolve_guide`'s 5-field `printf`/`read` contract put `dangling` (the one field that can legitimately
  contain embedded whitespace — rule filenames may have spaces, arm 40) in the MIDDLE. `read`'s
  word-splitting on an embedded space then shifted every field after it, turning `root_gone` into a
  malformed two-word string that could never equal `"yes"` — silently defeating the root-deletion check
  for any push that deleted the root behind a *spaced* dangling import elsewhere in the closure. Fixed by
  moving `dangling` to the LAST field (`read`'s last named variable absorbs the whole remainder of the
  line, embedded spaces and all — the standard idiom for this exact class of bug). Fixture: arm 55
  (redesigned mid-round — an earlier draft using a small surviving 2nd root let the unrelated
  vaporize-floor check also refuse the same push, masking whether this fix specifically was exercised;
  mirroring arm 47's large-surviving-root shape closed the confound, confirmed by the mutation matrix).
- **A-C-3 (Codex) — unclosed YAML frontmatter falsely exempted a rule from metering.**
  `has_paths_frontmatter` set `ok=1` the instant it saw a `paths:` line, without ever requiring the
  CLOSING `---` — so a malformed rule (`---`, `paths: …`, arbitrarily large body, no second `---`) was
  exempted forever, an unmetered fake-diet lane hiding *inside* the metering code itself, worse than the
  `^paths:`-anywhere bug arm 39 already guarded. Fixed: `ok` now requires the closing delimiter, and only
  if `paths:` was already seen. Fixture: arm 51. This fix incidentally made the PRE-EXISTING "frontmatter
  check = grep ^paths:" mutant (the one guarding the OPENING-delimiter requirement) **vacuous** against
  arm 39's specific content — caught by the mutation matrix itself (`NONE <-- VACUOUS FIXTURE`). Fixed by
  arm 58, which isolates the opening-delimiter requirement with content that has a `paths:` line AND a
  later stray `---` but never opens with `---` on line 1.
- **A-C-2 / A-C-2b (Codex + Pass C, independently) — directory-mode symlinks are invisible to the meter.**
  Git stores a symlink as a leaf blob (mode `120000`); `git ls-tree -r` can never see through one to a
  directory's contents. Claude Code documents directory symlinks as a sanctioned `.claude/rules/` pattern
  ("Symlinks are resolved and loaded normally," including the exact example `ln -s ~/shared-claude-rules
  .claude/rules/shared") — real content behind one is genuinely injected, but the meter either silently
  dropped it (a non-`.md` symlink name failed the `*.md` filter) or misclassified an `@import` traversing
  an intermediate symlinked directory as an ordinary "never existed" dangling import (weighed 0, warn
  only). Pass C independently reproduced both variants empirically (own scratch-repo testing) and rated
  it high-confidence; xtty's own repo has zero symlinks under `.claude/rules/` today, so the fix costs
  nothing in practice. Fixed via two new helpers (`is_dir_symlink`, `has_symlinked_ancestor`) and a new
  `unresolved_symlink` status that the caller refuses unconditionally (fail-closed — the meter cannot
  certify a byte count it cannot see behind, per D7). Fixtures: arm 53 (`.claude/rules/` directory
  symlink), arm 54 (`@import` through an intermediate symlinked directory).
- **A-C-5 (Codex) — a hand-merged foreign hook was silently clobbered by the NEXT routine `make` command.**
  The installer's foreign-hook recovery told users to "merge the logic from `$SRC` into `$TARGET` by
  hand" — which naturally retains `$SRC`'s sentinel comment — then classified ANY sentinel-containing file
  as "our own copy, always safe to re-copy." Since `hooks` is an order-only prerequisite of every routine
  `make build`/`test`/`install`/etc. (not just an explicit `make hooks`, which A-15-6's warning had only
  cautioned against by name), the very next routine command silently destroyed the hand-merged foreign
  logic with no warning. Fixed by tracking OWNERSHIP via a recorded hash (`xtty.guide-gate-hook-sha`) of
  what the installer itself last wrote: a sentinel match with no recorded hash, or a hash mismatch, now
  refuses rather than overwrites. Verified end-to-end (a real foreign hook, a real hand-merge, a real
  routine reinstall) that the merged logic survives. Fixture: arm 56. One-time transition cost accepted in
  writing: an already-armed clone from before this fix has no recorded hash yet, so its first post-fix
  reinstall refuses once with an actionable message rather than guessing — safe-side, matching D7.
- **A-C-6 (Pass C, empirically verified end-to-end) — a WORKTREE-scoped `core.hooksPath` was misdiagnosed
  as global, and the printed fix provably did not work.** `git config --worktree core.hooksPath …` (needs
  `extensions.worktreeConfig`) is invisible to `git config --local --get`, so the installer's two-way
  local/global check misdiagnosed it as global and printed `git config core.hooksPath "$DEST"` as the fix
  — which writes LOCAL scope and is silently outranked by the worktree-scoped value. Pass C ran the exact
  printed command and confirmed `git rev-parse --git-path hooks` was unchanged afterward: a dead end,
  reproducing in a third git-config scope the same "recovery advice that leads nowhere" bug class A-15-7
  already fixed for global-vs-local. Fixed by detecting `git config --worktree --get core.hooksPath`
  explicitly and printing the correct unset command for that scope. Fixture: arm 57.
- **Refuted, not fixed — Codex's import-MAXDEPTH claim.** Codex also claimed `MAXDEPTH=4` under-counts
  against a "5-hop" Claude Code loader limit. Checked against the live docs
  (code.claude.com/docs/en/memory) rather than accepted on the model's word: *"Imported files can
  recursively import other files, with a maximum depth of **four** hops."* `MAXDEPTH=4` is correct; the
  claim was false and no fix was made. This is the whole reason a second model's claims get verified
  against ground truth rather than trusted — see `cross-model-pairing-consult-research.md`'s
  never-corroboration rule.
- **Accepted as a residual, not fixed — Pass C's stale-tracking-ref siblings (confidence 0.45).** Two
  ladder lanes (the first-push fork-point rung, rung 0's `canonical` lookup) still trust a possibly-stale
  local tracking ref for `$REMOTE/main`, unlike the explicitly-hardened non-first-push lane (A-15-1). Both
  need an unusual precondition (history rewrite plus a stale fetch, or remote GC of still-locally-
  referenced objects) rather than an honest push — narrower than A-15-1's routine case. Documented in
  `design.md`'s Risks rather than fixed, per G-TARPIT-1 (don't harden a mechanical gate against every
  conceivable staleness variant) — `git fetch` before such a push closes both in practice.
- **Doc correction (Codex, medium) — the "only bypass is `--no-verify`" claim was too narrow.**
  `git -c core.hooksPath=/dev/null push` and `git -c xtty.guide-gate=false push` are also valid client-side
  bypasses (confirmed by reading the identity guard directly). `proposal.md` broadened to "any deliberate
  client-side act."

The mutation matrix was extended to also mutate `scripts/install-hooks.sh` (previously it could only
mutate `.githooks/pre-push`) — `INSTSRC`/`mut_inst()`, with `run()`'s installer argument defaulting to the
pristine file so existing hook-only mutants are unaffected. Final state: **58/58 fixtures**, **27/27
mutants** caught cleanly, 0 vacuous, 0 failed, run solo (never concurrently — the round-15 lesson still
holds).

**Re-verify by effect:** `bash scripts/test-guide-gate.sh` → `58 passed, 0 failed`; `bash
scripts/test-guide-gate-mutants.sh` → `All mutants caught cleanly (0 vacuous, 0 failed)`, exit 0. Confirm
A-C-1/A-C-2/A-C-2b/A-C-3 are real (not port artifacts) by real `git push` against a throwaway clone: a
directory symlink under `.claude/rules/`, an `@import` through one, unclosed frontmatter, and a spaced
dangling import composed with a root deletion should all `REFUSE` against the fixed hook.

## Round C.2 (2026-07-18, same day) — the bounded loop's FINAL round: 5 more real defects, one self-inflicted

Per `/xtty:cross-review`'s protocol, round C's fixes were checkpoint-committed and re-reviewed by a
**second** independent A‖B‖C pass (bounded N=2 — this is the last round before escalating any residual to
the human rather than looping further). Both soundness passes were briefed with round C's own fixes framed
explicitly as **claims to challenge, not established facts**. Both came back `needs-attention`, and — the
whole reason a second model pass exists — found **disjoint** real defects neither round C nor 14+ prior
review rounds had caught, including one **self-inflicted** by round C's own fix.

- **A-C-seen (Pass C, confidence 0.95, PRE-EXISTING — not introduced by round C) — `resolve_guide`'s
  `seen` dedup was a substring match, not exact membership.** `case " $seen " in *" $p "*)` tests whether
  `$p` is a substring of the space-joined accumulator, not whether it's an actual prior element — so a
  queued path whose TAIL exactly equals a later, genuinely distinct path (bounded by spaces — e.g. queued
  `.claude/rules/AAA bar.md` makes a later, unrelated `bar.md` register as already-seen) causes the later
  path to be silently skipped, its growth never added to `total`. Confirmed unchanged by round C's diff —
  this bug predates the whole session and survived every prior review round and the full fixture suite
  because none of them exercise a tail-suffix collision. Fixed by converting `seen` to a real bash array
  with exact per-element comparison. Fixture: arm 59.
- **A-C-2c (Codex + Pass C, independently, CONSENSUS) — `is_dir_symlink` resolved exactly ONE symlink
  hop.** A symlink pointing at ANOTHER symlink that in turn points at a directory fell through the
  `mode != 120000` check on the second hop and returned failure — **worse than the original A-C-2 bug**:
  not even flagged as `unresolved_symlink`, totally silent, zero warning. Fixed by making `is_dir_symlink`
  loop like `resolve_entry` already does (same 8-hop cap) instead of resolving exactly once. Fixture: arm 60.
- **A-C-2d (Codex) — an empty queue hardcoded `root_missing` unconditionally, discarding an
  already-detected `unresolved_symlink`.** If a directory symlink under `.claude/rules/` was the ONLY
  thing found (no `CLAUDE.md` at all), the empty-queue early return silently overwrote the correctly-set
  `status=unresolved_symlink` with a hardcoded `root_missing` — and the caller's "no baseline"/"unfetched
  baseline" lanes check `root_missing` FIRST and allow, waving through real content behind an undetected
  symlink as "no guide at all," worse than an ordinary refuse. Fixed by preserving whatever `status`
  already holds instead of hardcoding. Fixture: arm 61.
- **A-C-comma (Codex, medium) — a git filename may legally contain a comma, breaking the comma-joined
  dangling-path list.** Deleting a baseline-resolved import like `docs/a,b.md` produced
  `cur_dangling=docs/a,b.md,`; the comma-delimited split then mis-fragmented it into `docs/a` and `b.md`,
  neither of which resolves at the baseline as the ORIGINAL path — so `vaporized` stayed empty and the
  deletion was silently warned-and-allowed instead of refused. A-C-1's field-order fix (round 1) protected
  the OUTER field boundary but not the INNER comma-joined list within the `dangling` field itself. Fixed
  by switching the internal delimiter to the ASCII Unit Separator (`$'\x1f'`, `DANG_SEP`), a byte no real
  filename plausibly contains — the same class of fix as A-C-1, one layer deeper. Fixture: arm 62.
- **A-C-5b (Codex, the self-inflicted one) — round C's OWN A-C-5 recovery instructions caused the exact
  destruction they were written to prevent.** A-C-5 (round 1) added hash-tracking so a hand-merged foreign
  hook wouldn't be silently overwritten — but its recovery message told the user to run
  `git config xtty.guide-gate-hook-sha "$(git hash-object $TARGET)"` to "record it as ours," which makes
  `installed_hash == recorded_hash` on the VERY NEXT run — precisely the condition the guard treats as "a
  verified prior install of ours, safe to re-copy." **Verified end-to-end by effect**: a scratch repo where
  the exact printed instructions were followed literally had its hand-merged hook destroyed by the next
  routine reinstall. The fix is structural, not cosmetic: `xtty.guide-gate-hook-sha` must ONLY ever be
  written by the installer's own successful `install` step, NEVER printed as a user-facing recovery
  instruction — there is no config command that can mark hand-edited content "safe to keep AND
  auto-upgrade," since those are contradictory. The only honest recovery paths left are (a) an explicit,
  unambiguously destructive `make hooks` re-run, or (b) leave it alone forever and maintain the merge by
  hand — the installer will simply keep refusing on every future run, safe by construction rather than by
  documentation. Fixture: arm 63 (asserts BOTH that the printed text never mentions the dangerous config
  key, and that the merge survives 3 repeated routine reinstalls).

**Refuted in round 1, reconfirmed correct here:** Codex's `MAXDEPTH=4` claim (checked against the live
docs: "a maximum depth of **four** hops" — correct, no fix). **Adjudicated as accepted residuals, not
fixed** (documented in `design.md`'s Risks section): (1) a literal embedded NEWLINE in a dangling path
still isn't closed by A-C-1's field-order fix (confidence 0.85 — an R3 adversarial-construction-only case,
unlike the realistic embedded-space case arm 40 exercises); (2) checking out an OLD commit and running a
routine `make` target from it can downgrade the shared common-dir hook for every worktree (a property of
D2's whole shared-hooks-dir architecture, not a round-C regression, and requires the deliberate act of
building from historical history rather than the branch tip). **Considered and judged NOT a defect:**
Codex's claim that deleting a non-root eager root isn't flagged as a "deletion" — this is the comparator's
correct, intended shrink-always-allowed behavior (D5); only the ROOT's disappearance has the
self-disabling-gate property A-1's special handling exists to catch. Two low-severity, safe-direction
(over-refuse only, never under-refuse) findings from Pass C were left as-is: CRLF frontmatter parsing and
a narrow hash-tracking self-lock requiring deliberate config-clearing.

Final state after round C.2: **63/63 fixtures**, **32/32 mutants** caught cleanly, 0 vacuous, 0 failed,
run solo throughout. This is the bounded loop's last round — per protocol, no round 3 was launched; the
residuals above were escalated in writing rather than chased further.

**Re-verify by effect:** `bash scripts/test-guide-gate.sh` → `63 passed, 0 failed`; `bash
scripts/test-guide-gate-mutants.sh` → `All mutants caught cleanly (0 vacuous, 0 failed)`, exit 0. Confirm
A-C-seen/A-C-2c/A-C-2d/A-C-comma by real `git push` against a throwaway clone (a tail-colliding import
growth, a 2-hop symlink chain, a symlink-only guide, a comma-named deleted import should all `REFUSE`);
confirm A-C-5b by literally executing the installer's OWN printed recovery commands against a hand-merged
foreign hook and running `make hooks`'s equivalent 3 more times — the foreign logic must survive.

## Round C.3 (2026-07-18, same day) — an independent, automated stop-gate: 2 more real gaps

`/xtty:cross-review`'s own bounded 2-round loop closed with round C.2. Separately, this session's **Codex
stop-time review gate** (an automated pass that fires at end-of-turn and can block session end — distinct
from the on-demand `/xtty:cross-review` command; the same mechanism that caught A-15-3 earlier this
session) fired on round C.2's own commit and blocked with two more real, verified findings.

- **A-C-2e — a directory symlink whose OWN NAME ends in `.md` sailed past `is_dir_symlink` entirely.**
  The discovery loop's directory-symlink check only ran inside the `*)` (non-`.md`) branch of a
  `case "$r" in *.md) ;; *) ... ;; esac` — so `.claude/rules/shared.md -> ../../external-rules/` (a
  plausible, even likely name for a symlinked directory) took the `*.md)` no-op branch straight into
  `queue`. `resolve_entry` then followed it, but its mode check only special-cases `120000` (symlink);
  once resolved to a `040000` (tree) object, it fell through to `printf '%s %s' "$blobid" "$path"` as if
  the tree's SHA were a file blob — and `git cat-file -s <tree-sha>` returns the TREE's own tiny
  serialized size, not the real recursive byte content behind it. **Verified empirically: the push was
  ALLOWED (exit 0) with 5000 real bytes completely uncounted.** Fixed by checking `is_dir_symlink` on
  EVERY entry, unconditionally, before the `.md`-suffix filter — not only in one branch of it. Fixture:
  arm 64. This restructuring retired the original round-1 "A-C-2" mutant (its two-branch search text no
  longer existed) — its intent lives on, structurally superseded, in a combined "A-C-2/A-C-2e" mutant
  (mirroring the earlier A-15-2 → A-15-2b retirement pattern exactly).
- **A-C-5c — round C.2's OWN recovery message printed a discard instruction that does not exist.**
  A-C-5b's message said "you explicitly re-run 'make hooks' to DISCARD it and install the pristine
  tracked hook" — but a bare re-run invokes this SAME installer, hits this SAME mismatch branch, and
  refuses again. **Verified empirically: two bare re-runs, refused both times, byte-identical file.** The
  exact "recovery advice that leads nowhere" bug class this project fixed under A-15-7 for a different
  scope, reintroduced by A-C-5b's own fix in this same session. Fixed by adding a REAL, working discard
  path — `XTTY_GUIDE_FORCE=1 make hooks` — gated by an explicit env override (never a default, mirroring
  the hook's own `XTTY_GUIDE_CEILING`/`XTTY_GUIDE_FLOOR` idiom: a silent env leak must never discard a
  stranger's hook). A bare re-run still safely refuses, unchanged; only the explicit force signal
  discards. Verified both directions. Fixture: arm 65 (asserts both: a bare re-run still preserves the
  foreign hook, AND `XTTY_GUIDE_FORCE=1` actually discards it).

One more originally-round-2 mutant (A-C-5b's own) went vacuous as a side effect of A-C-5c's wording change
to the exact line it searched for — fixed by updating its search string to match, no narrative change (the
underlying concern — the recovery text must never mention the self-defeating config key — is still
independently guarded by arm 63 regardless of exact wording).

Final state after round C.3: **65/65 fixtures**, **33/33 mutants** caught cleanly, 0 vacuous, 0 failed, run
solo throughout.

**Re-verify by effect:** `bash scripts/test-guide-gate.sh` → `65 passed, 0 failed`; `bash
scripts/test-guide-gate-mutants.sh` → `All mutants caught cleanly (0 vacuous, 0 failed)`, exit 0. Confirm
A-C-2e by real `git push`: a `.claude/rules/shared.md` directory symlink (name ending in `.md`) with real
content behind it must `REFUSE`. Confirm A-C-5c by executing the installer's OWN printed instructions
literally: a bare re-run of the installer against a hand-merged mismatched hook must still refuse (the
foreign logic survives); `XTTY_GUIDE_FORCE=1` re-run of the SAME installer must actually discard it.

## Round C.4 (2026-07-18, same day) — a Codex-only single-model pass (user-requested): 4 more, plus 3 self-found

Per explicit user request, a FOURTH review ran as a single-model pass — Codex `gpt-5.6-sol` only, no
companion Opus, no Fable, briefed with all three prior rounds' fixes framed as claims to challenge and
specifically asked to check whether the pattern of "each round finds a gap in the PRIOR round's own fix"
(round 2 found gaps in round 1; round 3 found gaps in round 2) continued into round 3's own fixes.

- **A-C-gitlink — a git submodule (gitlink, mode 160000) at `.claude/rules/` is completely invisible to
  the meter.** `is_dir_symlink` only recognizes modes `040000`/`120000`; a gitlink fails both checks and
  falls through the non-`.md` filter untouched. If `.md`-suffixed, `resolve_entry` fell through further:
  its mode check only special-cased `120000`, so a gitlink's COMMIT SHA got treated as a file blob, and
  `git cat-file -s` on a commit object returns the commit's own tiny size, not the submodule's real
  (checked-out, genuinely eagerly-loaded) content. **Verified empirically with a real submodule**: 5000
  bytes went completely uncounted, push allowed. Fixed with a new `is_gitlink` helper (checked alongside
  `is_dir_symlink` in rule discovery) and a `resolve_entry` guard refusing to resolve mode `160000` (later
  widened to also cover `040000`, see A-C-tree below). Fixture: arm 66.
- **A-C-phys — a raw FILESYSTEM symlink at `<git-common-dir>/hooks` defeats the ownership guard, and this
  session's OWN `XTTY_GUIDE_FORCE=1` fix made it WORSE.** The existing guard only inspects
  `core.hooksPath` (a git-config-level redirection); a `.git/hooks -> /shared/hooks` symlink is a
  filesystem-level mechanism the guard never considered, with `core.hooksPath` staying unset throughout.
  **Verified empirically**: a bare install correctly detected the shared file as foreign (no sentinel) and
  left it alone — but `XTTY_GUIDE_FORCE=1`, the round-3 recovery path this SAME session had just added,
  bypassed that check entirely and silently overwrote the shared file, exactly the cross-repo harm arm 3
  already tests for the config-level case. Fixed with an UNCONDITIONAL physical-path containment check
  (`cd "$DEST" && pwd -P` must resolve inside `git rev-parse --git-common-dir`'s own physical path) that
  runs BEFORE the `FORCE` gate and can never be bypassed by it — FORCE is scoped to "is this content
  verifiably ours," never to "are we even writing inside our own repository." Fixture: arm 67.
- **A-C-arm-verify — a silently-failed `git config` write left the hook installed but unarmed, with zero
  diagnostic.** Both arming writes use `|| true` (by design — this installer is CANNOT-FAIL). **Verified
  empirically**: a pre-existing `.git/config.lock` made the `xtty.guide-gate` write silently fail while
  the installer still exited 0 and the hook file was genuinely present — a "looks protected but isn't"
  state invisible to the user. Fixed by reading back what was actually recorded and printing a non-fatal
  WARNING when arming didn't stick (still never fails the build). Fixture: arm 68.
- **Makefile — `build-core` (XttyCore-only builds) was the one routine entry point missing the order-only
  `hooks` prerequisite** every other routine target (`build`/`test`/`test-core`/`run`/`install`/`setup`)
  carries — a real, verified gap (`grep` confirmed), not a design choice. Fixed: `| hooks` added. Fixture:
  arm 69 (asserts `make -n build-core` fires the installer).

**Self-found while verifying A-C-gitlink — the SAME pattern recurred a third time, inside the same round:**
the ancestor-only disambiguation this session already built (A-C-2b) doesn't cover the TERMINAL path
naming an unsupported shape directly (no path separator at all). Verified empirically with real pushes:
- **A-C-tree/A-C-terminal-gitlink** — `@sublink` (a bare gitlink import, no separator) and `@linkdir` (a
  bare directory-symlink import) both escaped: `has_symlinked_ancestor` returns false immediately for a
  single-segment path ("nothing to check as an ancestor"), and `resolve_entry` had no guard against
  resolving down to a TREE object (`040000`) either — the exact same mistaken-identity bug as the gitlink
  case, just for symlinks-to-directories imported with no trailing segment. Fixed: widened `resolve_entry`'s
  guard to `case "$mode" in 040000|160000) return 1 ;; esac`, and the caller's disambiguation to
  `has_symlinked_ancestor || is_dir_symlink || is_gitlink` on the TERMINAL path. Fixtures: arms 66b, 66c.
- **A-C-gitlink-ancestor** — an `@import` traversing THROUGH a gitlink ancestor (`@subrepo/deep.md` where
  `subrepo` is itself a submodule) needed `has_symlinked_ancestor`'s per-component mode check widened from
  `120000` alone to `case "$mode" in 120000|160000)`. Fixture: arm 66d.

Two more mutants went stale from this round's OWN restructuring (their search text no longer matched after
later edits in the SAME round — the fourth time this exact self-inflicted pattern occurred this session:
round 2 found gaps in round 1, round 3 found gaps in round 2, and now round 4's own mid-round edits broke
two of its own freshly-written mutants before the round even finished) — both repaired to match the final
code, verified non-vacuous.

Final state after round C.4: **72/72 fixtures**, **37/37 mutants** caught cleanly, 0 vacuous, 0 failed, run
solo throughout. This closes the Codex-only single-model pass; per the user's request, no Pass A/C or Fable
ran this round.

**Re-verify by effect:** `bash scripts/test-guide-gate.sh` → `72 passed, 0 failed`; `bash
scripts/test-guide-gate-mutants.sh` → `All mutants caught cleanly (0 vacuous, 0 failed)`, exit 0. Confirm
A-C-gitlink with a real `git submodule add` at `.claude/rules/shared`: must `REFUSE`. Confirm A-C-phys with
a real `.git/hooks` filesystem symlink to a directory outside the repo: `XTTY_GUIDE_FORCE=1 make hooks`'s
equivalent must NOT write there. Confirm A-C-arm-verify with a pre-existing `.git/config.lock`: the
installer must print a WARNING, not stay silent.
