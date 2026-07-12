# Cross-review ledger — `brief-cross-review-pass-b` (the A' dogfood)

> **Advisory in its entirety. Gate-inert.** Nothing here gates archive. This ledger records the change's
> own dogfood: `/xtty:cross-review`'s Pass B was run on this change **both blind and briefed (A')**, to
> test — by effect, on the change itself — whether the brief the change adds actually sharpens the review.

## Header

| Field | Value |
| --- | --- |
| **Reviewed range** | base `B = 8108081` (parent of the propose commit) .. HEAD `155feb7` — 6 files |
| **Scope (mechanical)** | **`exit 0`** — a *live demonstration of the retrospective-classifier finding* (F4): this change **will** be in scope once its `.claude/` edits land, but at propose time only its allowlisted artifacts exist. Human launched anyway. |
| **Passes run** | Pass B (Codex `gpt-5.6-sol`) **twice on the identical range**: RUN 1 blind (no brief), RUN 2 briefed (A'). Both `adversarial-review`, hardcoded read-only. xtty **CLEAN** after both. |
| **Purpose** | Dogfood the A' fix on the change that proposes it. |

## The contrast — what the brief did, and what it cost

| | RUN 1 — BLIND | RUN 2 — BRIEFED (A') |
| --- | --- | --- |
| verdict | needs-attention, 2×medium | needs-attention, 1×high + 1×medium |
| engaged the 5 briefed claims? | **no** (only what the diff shows) | **yes** — explicit verdicts on D2 (refuted), attention-vs-range (dismissed the worry, correctly), D3 read-only (endorsed) |
| unique catch | **shared brief → opaque two-model consensus** | **D2 "verbatim" overstated** (`positionals.join(' ').trim()`; version-pinned to 1.0.6) |
| both found | the brief-file fallback is **broken/unimplementable** | same, escalated to **high** |

**A' works** (briefed run walked the checklist and returned verdicts on the exact uncertain claims), **and A' has a real cost** — the blind run's #1 finding (opaque consensus) was **crowded out** of the briefed run. **That is R1 in this change's own design, confirmed by effect.**

## Findings + resolutions (all three real; all folded in)

| # | Run | Sev | Finding | Resolution |
| --- | --- | --- | --- | --- |
| **B1** | both (blind #2 / briefed #1) | high | **Brief-file fallback is unimplementable.** The digest excludes exactly `cross-review-ledger.md`; a new brief file either enters the reviewed-state digest (committed) or trips the dirty-tree refusal (untracked) — contradicting the gate-inert claim + task 4.3. | **FIXED — fallback DROPPED.** Inline only; overflow (if ever) rides the already-excluded advisory ledger, never a new file. Spec 2nd-paragraph rewritten, design D2, proposal, task 1.5. |
| **B2** | briefed | medium | **D2 overstates "verbatim".** Code is `positionals.join(' ').trim()` — strips/normalizes whitespace; the effect test proves *semantic engagement*, not byte-preservation. Also version-pinned to companion 1.0.6. | **FIXED.** D2 narrowed to *semantic delivery + internal newlines intact*, with a version-sensitivity mitigation (re-probe on companion version change). Task 3.2 corrected. |
| **B3** | blind (top finding) | medium | **Shared brief → opaque two-model consensus** + (by effect) it **crowds out** open-ended findings = R1. | **FIXED — new decision D2a + spec guards.** Brief is **additive** (check the claims *and* report outside them); **no consensus** on shared-brief-only findings; brief **recorded in the ledger**; drill digest presented **as claims to challenge**. |

## What the briefed run correctly *dismissed* (my worries, laid to rest)

- **attention-vs-range coexistence** (the ADDED requirement vs the existing "focus doesn't restrict what's reviewed") — *"not contradictory"*. Correct: a brief scopes attention, not the diff.
- **D3 (reject `task --write`)** — *"keep D3's read-only decision … neither requires a blocking redesign on the current evidence."*

## The meta-result

This is the cleanest possible validation of the A' change: **run on itself, the brief made the review measurably sharper on the author's stated uncertainties — and simultaneously demonstrated its own documented cost (R1), which the change now guards against.** The exit tell from the research doc (§8) is met: a briefed read-only pass engaged the design's specific claims, and the two real defects it found were both fixed.

## Authority restatement

Advisory. No gate force. The model did **not** tick task 4.2, computed no digest, wrote no attestation line. A genuine archive still requires the human to read this ledger, run `scripts/cross-review-digest.sh` themselves, and attest.

---

## Round 2 (briefed, additive-instruction) — ⚠️ and the diminishing-returns cliff

Re-ran Pass B (briefed A', **with the D2a additive instruction** — "check these claims AND report anything outside them") on the round-1-fixed state (`B..HEAD` = `639b3b0`). **The additive instruction worked, in the most convincing way: Codex used it to critique the additive instruction itself** — every finding went beyond the fix-verification checklist. That validates D2a by effect. It also produced four findings; adjudicated against one discriminator — *does this change what gets BUILT, or elaborate the spec of an unbuilt tool?*

| # | Sev | Finding | Disposition |
| --- | --- | --- | --- |
| **R2-4** | medium | **The B2 fix wasn't propagated to all surfaces** — task 1.1 (the point-of-tick authority) and proposal.md still said *"survives verbatim"*; R3 + proposal impact still referenced the *dropped* file fallback. | **FIXED** — changes what gets *built*; propagated verbatim→semantic to task 1.1 + proposal, stripped the stale fallback refs. |
| **R2-2** | medium | **The "overflow rides the ledger" fallback is under-specified** (no pre-pass commit / pointer / read instruction; the ledger persists *after* the passes run, so it can't reach them). | **FIXED subtractively** — dropped ledger-overflow entirely; an over-budget brief is **compacted with a noted compaction**, never spilled. |
| **R2-1** | medium | **The additive *instruction* doesn't restore an independent blind slice** — both passes still share framing; "consensus only when both rest *only* on the brief" is hard to adjudicate. Proposed: keep one pass **blind**. | **LOGGED, not adopted** (design Open Questions). It reintroduces under-briefing by design, to protect an *advisory* consensus flag that barely fires and is now human-auditable. If the flag proves untrustworthy in **use**, soften the flag — don't redesign briefing. Decide from usage. |
| **R2-3** | medium | **Version re-probe has no persistent trigger** — it lives only in a one-time verify task; an upgrade could silently regress arg parsing. Proposed: record + compare the companion version in the worker. | **DEFERRED** (design Open Questions) — cheap to add if a version bump ever regresses briefing; premature to build now. |

### ⚠️ The cliff — and why round 2 is the last review round

`brief-cross-review-pass-b` is **0/12: the command edit does not exist yet.** This is round 2 of adversarially reviewing the *spec* of an unbuilt dev tool, and adversarial review never returns zero (**G-TARPIT-3**) — each round mints fresh "real" findings. This repo's own **G-TARPIT-4** names the failure precisely: *"~16 rounds on a proposal at 0 tasks; a dev tool is validated by **building and using it**."* Round 1 was worth it (it proved A' works and killed the unimplementable fallback). Round 2 returned one build-affecting bug (R2-4) and otherwise spec-polish. **Past the cliff.** No round 3. The real test is **implementing the two command edits and running `/xtty:cross-review` on a real change with a populated brief** — the exit prescribed by the change's own research (§8). Findings 1/3 are logged; decide them from that usage, never from another review pass.

---

## Round 3 — landed-change dogfood (human-launched `/xtty:cross-review`, the A' fix reviewing itself)

> This is exactly the "real test" round-2's cliff note prescribed: the command edit is now **committed**, so this run exercises the *real* briefed Pass B on the change that ships it. It found one real reliability gap (Finding 1) that a naive future run would hit — and the fix was proven by effect *in this very run*. **Advisory in its entirety; gate-inert.**

### Header (transparency contract)

| Field | Value |
| --- | --- |
| **Reviewed range** | base `B = 8108081` (parent of the propose commit `155feb7`) .. HEAD `522c7ea` — **8 files** *(pre-fix HEAD; the round-3 fixes below move HEAD forward — the human attests the fixed state)* |
| **Reviewed files** | `.claude/commands/xtty/cross-review.md`, `AGENTS.md`, and the change dir (`.openspec.yaml`, `cross-review-ledger.md`, `design.md`, `proposal.md`, `specs/cross-model-review/spec.md`, `tasks.md`) |
| **Scope (mechanical)** | **exit 10 — in scope** (`.claude/commands/xtty/cross-review.md` is outside the docs/tracker allowlist). Now that the command edit is committed, the retrospective classifier correctly reads in-scope — contrast the propose-time run's exit 0 (F4). |
| **Passes run** | **A** (Opus critic — reused from task 4.1 this session: VERDICT **COHERENT**, `Definition: v4`, on the content-identical reviewed state modulo the digest-neutral 4.1 tick) ‖ **B** (Codex `gpt-5.6-sol`, briefed, backgrounded) ‖ **C** (inline Opus soundness, same brief). |
| **Models / effort** | Pass B: `gpt-5.6-sol`, effort codex-config-governed (`xhigh` expected; not invocation-pinned). Pass C: inline Opus. Pass A: `xtty-openspec-critic` v4. |
| **Diff regime** | **Summary-only** — 8 files > the ≤2-file inline threshold (`lib/git.mjs`), so Codex self-collected and **still engaged the brief** (this is what resolves Finding 3). |
| **Brief** | The 6-claim design brief (delivery / additive-guard / no-in-repo-file / reject-`task --write` / advisory / shared-framing) + a drills-already-run digest + the additive instruction. **Staged out-of-repo (`mktemp`) and read into one positional** — the very idiom this run then hardened into the command. Recorded here so the shared framing behind any consensus flag is auditable. |
| **Companion version** | **1.0.6** (arg-survival verified against this version — a later bump is a visible re-probe trigger). |

### The union ledger — every finding, every resolution

| # | Pass(es) | Sev | Finding | Resolution |
| --- | --- | --- | --- | --- |
| **1** | C | **high** | **Delivery analyzed only at the companion layer; the shell layer that actually carries the brief is unanalyzed and can expand / command-substitute / word-split it.** "internal newlines intact" holds only if the brief reaches `node` as ONE safely-quoted positional; a brief about this tool carries backticks/`$`/quotes. The by-effect probe used metacharacter-free prose, so it never exercised this. | **FIXED this round — proven by effect.** The command now prescribes the out-of-repo `mktemp` → `BRIEF="$(cat …)"` single-positional idiom (the exact channel this run used, with a brief containing backticks + `$`). Design D2 gains the shell-layer correction; spec + proposal + task 1.5 narrowed to match. |
| **2** | C | med | **D2's "no brief file" over-generalized from "no in-repo file"** — an out-of-repo temp file is digest-invisible + metacharacter-safe, the robust channel D2 wrongly forbade. | **FIXED this round.** Narrowed to **no IN-REPO brief file** across spec + design D2 + proposal + task 1.5; out-of-repo staging is now the *prescribed* channel. |
| **3** | C | med | **"Verified by effect" was established only on the inlined small-diff path**, not the >2-file summary-only regime that *motivated* the change. | **RESOLVED by this run.** This review's range is 8 files (> 2) ⇒ Codex self-collected (summary-only) ⇒ brief still engaged. Design D1 now records the evidence spans both paths. **No new drill built** (would be tar-pit). |
| **4** | B | med→ low | **Companion upgrades can silently restore blind review** — delivery verified only vs 1.0.6, command resolves the *highest* version, ledger records version *after* invocation, and the companion **never echoes received focus** ⇒ no positive delivery confirmation. | **DISMISSED — deferred by design (R2-3).** This run is on the verified 1.0.6 baseline; the by-effect engagement check (findings reference the brief) is the standing contract. The persistent version-trigger stays logged/deferred (cheap to add when a bump regresses; premature now). The sharpened "no-echo" point is recorded in design Open Questions. |
| **5** | **B ∧ C** | med / low | **Shared framing makes the two-model-consensus signal non-independent and hard to adjudicate** (B-1 + C-4 — a genuine semantic agreement). | **DISMISSED — logged R2-1, and this run IS the usage datum.** Both passes raised it resting **only** on briefed claim 6, so per the change's own rule it was **NOT flagged as consensus** (see below). Disposition upgraded to **resolved-by-usage**: the guard behaved correctly on its first real run; if the flag ever over-fires in use, soften it — do not reintroduce a blind slice. |
| **6** | C | low | **`cross-review.md` still said "verbatim in meaning"** — the exact wording the change set out to correct (the point-of-tick authority file, G13). R2-4 had claimed this was propagated everywhere; it wasn't. | **FIXED this round.** Reworded to "semantic content and internal newlines intact — not byte-identical". |
| **7** | **A ∧ B** | low | **`AGENTS.md:24` open-changes row stale** (`0/12` vs `openspec list` `10/12`). Objective disk-drift, two independent passes (not brief-dependent). | **DEFERRED to the 4.3 archive reconcile (already scheduled).** Fixing it now would edit a reviewed path — perturbing the digest the human is about to attest — and it is overwritten wholesale when the row moves to *Shipped and archived*. |

### Consensus adjudication — the D2a guard, demonstrated by effect

Finding 5 was raised by **both** soundness passes — the one place a naive merge would stamp "two-model consensus." Both rest **only** on shared briefed claim 6, so the rule **suppressed the flag**. This run is self-demonstrating: the change's own consensus-suppression guard fired correctly on its first real workload. That is the precise usage evidence R2-1 asked for — which is why Finding 5's disposition is *resolved-by-usage*, not another open question.

### Bounded loop → stop after one fix round (N=2 ceiling not needed)

Round 1 (this run) found one real reliability gap (Finding 1) whose fix is **proven by effect in the run itself**. Per the repo's G-TARPIT discipline and the change's own "decide from usage, not another review round", a prose-instruction fix proven-by-effect is re-reviewed by **coherence + `openspec validate`** (both green) — **not** another paid A‖B‖C round, which only mints fresh non-zero findings (G-TARPIT-3). **No round 2.** Residuals handed to the human: **R2-3** (version-drift / no-echo — deferred, decide from usage); **R2-1** (shared-framing consensus — resolved-by-usage this run); **tracker drift** (reconcile at 4.3).

### Authority restatement

**Advisory. Zero gate force. "Converged" means nothing here.** The model applied the round-3 fixes (pre-attestation, checkpoint-committed) but did **not** tick task 4.2, computed **no** digest, and wrote **no** attestation line. A genuine archive still requires the **human** to read this complete ledger, run `scripts/cross-review-digest.sh brief-cross-review-pass-b` themselves, and attest to the fixed HEAD.
