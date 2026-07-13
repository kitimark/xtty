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
