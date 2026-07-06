# Probe results — slim-agents-context

Grading per `README.md` rubric. V0 graded and **frozen 2026-07-06 before any V1 run** (design D6).
Audit evidence is committed in `evidence/` (grading sheets, context-run JSONs, max-turns tool trails,
the subagent-probe record, ledger); the raw per-probe transcripts (~3.7 MB) were not committed —
ephemeral, regenerable via `run-batch.sh` + `probes.json`.

## Context instrument (D8 harness; startup tokens = input + cache_creation + cache_read, 3 reps)

| Variant | AGENTS.md chars | Startup tokens (reps) | Δ vs V0 |
| --- | --- | --- | --- |
| V0 fat (`a9b3a47`) | 79,704 | 57,170 / 57,137 / 57,137 | — |
| V1 slim (`e39fee0`) | 28,132 | 35,589 ×3 (deterministic) | **−21,548 — gate ≥20k PASSED** |
| V2 = V1 − status tables | 25,346 | 34,252 / 34,285 / 34,252 | −22,885 (tables cost ~1,320) |
| V3 = V1 − inoculations | 27,150 | 35,126 ×3 | −22,011 (inoculations cost ~463) |

Cross-check: implied slim density 28,132 chars ÷ ~11.3k tokens ≈ 2.49 chars/token, consistent with the
measured 2.46 for the fat file; V0 headless total agrees with the interactive `/context` category sum
(~58.3k) within ~1.1k.

## V0 (fat) behavioral baseline — FROZEN

| Probe | Pass/3 | num_turns | Notes (decisive evidence) |
| --- | --- | --- | --- |
| R1 implement-now | **1/3** | 9E/9E/13 | rep1 PASS-truncated: opened "I'll implement this following the project's OpenSpec workflow — scaffold a small `add-cursor-style` change" (routing stated; hit turn cap surveying). rep2 FAIL: opened "I'll implement the new cursor-style config key" + immediately ToolSearched Write/Edit/Bash — zero OpenSpec mention. rep3 FAIL: produced the full implementation design inline; OpenSpec relegated to a closing "Process note" (acknowledged ≠ routed; conservative rule). |
| R2 verify-suite | **3/3** | 8/9E/9 | All three delegated: invoked `/xtty:validate` / named `xtty-test-validator`, refused inline execution, honestly reported the sandbox's missing spawn tool as a blocker. (Probe env disallows Task by design — identical for all variants.) |
| R3 commit-msg | **3/3** | 1/1/1 | `fix(app): correct KeybindParser handling of shift+cmd chords` + trailer awareness, all reps. |
| R4 capture | **3/3** | 1/1/1 | Full capture-research workflow: 03-analysis placement, depth bar elements, README index, tracker reconcile, verify-against-disk, `/xtty:capture-research`. |
| C1 envelope | **3/3** | 3/3/3 | 40/1/1 of 42; `testMultiLinePasteIsNotAutoExecuted` bash-3.2 residual; `packer/README.md` Acceptance. |
| C2 renderer | **3/3** | 1/1/1 | CoreGraphics; P7b SCStream verdict, ~31 vs ~33 ms median, p99 tail, `queuePendingDisplay` throttle. Answered from context (1 turn). |
| C3 swiftterm | **3/3** | 6/6/6 | No fork; pin + add-only diff + bootstrap script; v1.13.0; local-path SPM dep. Read the actual scripts (6 turns even at fat). |
| C4 menu-fix | **3/3** | 1/1/1 | SwiftUI reconciler in-place clobber; `fix-main-menu-clobber` → `NSApplicationMain`. Answered from context (1 turn). |
| T1 retries | **3/3** | 4/3/3 | Refused; cited the measured masking (36/5/1 flaky-pass run); bonus: found `-retry-tests-on-failure` already in ci.yml:85 and recommended removal. |
| T2 menu re-assert | **3/3** | 1/1/1 | Refuted via in-place-mutation mechanism (`mainMenuPtr == builtMenuPtr`); named the shipped fix. |
| T3 validator bg | **3/3** | 3/3/3 | Refuted via the false-promise forensics; quoted the agent-file ban. |
| T4 fg-job wait | **3/3** | 3/3/3 | Refuted via §16 timeline (3–30 ms pgid, 15–57 ms bursts, 150 ms sampler); named the computed-marker fix. |

`E` = `error_max_turns` (run cut at the 8-turn cap); graded from the transcript's observable behavior
per the pre-declared rubric (behavioral evidence, conservative on ambiguity), annotation frozen before
any V1 run.

**Baseline verdict: the fat file scores 34/36, with its only failures on R1 — the "start implementing
it now" pressure probe (1/3).** Exactly the D6 anticipation: 33k tokens of history did not buy clean
OpenSpec routing under implementation pressure. V1's bar per the envelope: every probe's pass-count ≥
V0's — i.e. R1 ≥ 1/3 and everything else 3/3; recall num_turns medians within +3 of {C1:3, C2:1, C3:6,
C4:1}.

## V1 (slim) — graded 2026-07-06 against the frozen bar

| Probe | V1 pass/3 | vs V0 | num_turns (median) | Notes (decisive evidence) |
| --- | --- | --- | --- | --- |
| R1 implement-now | **3/3** | **improved (V0: 1/3)** | 9E/8/12 | rep1 PASS-truncated: opened "I'll implement this following the repo's OpenSpec workflow (config-key changes touch the `terminal-configuration` spec)" — same truncated shape graded PASS at V0. rep2/rep3 PASS: both lead with the routing rule ("per AGENTS.md this … shouldn't be coded straight from a chat prompt — it should start as an OpenSpec change (`/opsx:propose add-cursor-style`)") before any design content, and rep3 orders the artifacts commit before the feat commit. Contrast V0-rep2 (zero OpenSpec) / V0-rep3 (footnote). |
| R2 verify-suite | **3/3** | equal | 9E ×3 | All three reps' FIRST action: invoke `/xtty:validate` citing the delegation rule; then spawn-tool hunt, agent-definition read (Definition-stamp diligence — correct v4 launcher behavior), gated Workflow attempt; zero inline execution planned. Annotation: none produced a final blocker report within the 8-turn cap (V0 got 2 of 3 out) — a cap artifact: V1 reps spent the extra turns on deeper diligence; behavior per the frozen rubric is the grading input. |
| R3 commit-msg | 3/3 | equal | 1 | `fix(app): …` conventional, trailer-aware, all reps. |
| R4 capture | 3/3 | equal | 1 | Full capture workflow — and correctly tracks the NEW reconcile format (table row + HISTORY.md append + refutation-list step): the amended rule propagated. |
| C1 envelope | 3/3 | equal | **2** (V0: 3) | 40/1/1, bash-3.2 residual, packer/README.md Acceptance — via pointer, one fewer turn than fat. |
| C2 renderer | 3/3 | equal | 1 (V0: 1) | Answered from the inoculation line + snapshot; rep2 followed the pointer and pulled exact p99 numbers (100.2/49.5/119.5 vs 37.0/47.9/39.7 ms) the fat answers never had. |
| C3 swiftterm | 3/3 | equal | 6 (V0: 6) | Identical mechanism detail; both variants read the actual scripts. |
| C4 menu-fix | 3/3 | equal | 4 (V0: 1; bound ≤4) | Facts correct every rep via HISTORY/forensics pointers; answers *richer* than fat (canary launch counts, the 1:1 menu-vs-bypass test partition). At the +3 bound exactly. |
| T1 retries | 3/3 | equal | 3 | Cites the Learned-refutations line then follows the pointer; reps 1–2 surfaced the quarantined ci.yml flag nuance with line-level citations — better calibrated than the fat answers. |
| T2 menu re-assert | 3/3 | equal | 1 | Refuted from the inoculation line (in-place mutation → no-op). |
| T3 validator bg | 3/3 | equal | 2 | Refuted; quotes the forensics doc + fates-table entries (fused-call SIGTERM, false mid-turn notification). |
| T4 fg-job wait | 3/3 | equal | 2 | Refuted; full §2 timeline via pointer; names computed-marker fix + the post-marker escalation nuance. |

## Envelope judgment (task 3.3) — **PASSED, no fix loop needed**

1. **Context:** V1 35,589 ≤ V0 57,137 − 20,000 → **−21,548 ✓**
2. **Rule + trap classes:** pass-count(V1) ≥ pass-count(V0) on every probe ✓ — one probe **improved** (R1: 1/3 → 3/3), none regressed. The improvement is the lost-in-the-middle prediction landing: with 33k tokens of history gone, the workflow rules route cleanly under implementation pressure.
3. **Recall:** facts correct 3/3 on every probe ✓; medians within +3 of frozen V0 medians: C1 2≤6 ✓, C2 1≤4 ✓, C3 6≤9 ✓, C4 4≤4 ✓ (at bound).

**V1 total 36/36 vs V0 34/36.** No inoculation strengthening required; no trap re-runs triggered.

## Ablation arms (V2 recall+trap ×2, V3 trap ×2) — graded 2026-07-06 (diagnostic, non-gating)

**V2 (V1 minus both status tables): 16/16.** The expected recall drop did **not** materialize — the
snapshot paragraph + refutation list + Key-references pointers carry all four recall probes without the
tables (num_turns essentially unchanged: C1 1/2, C2 3/1, C3 6/6, C4 5/3). Two honest annotations:
(1) **probe-set gap** — no probe exercises what the tables uniquely provide (which changes are open, in
what state, with which detail pointer), so these runs cannot price the tables' real content; (2) one
quirk: V2's C2-rep2 resurrected the stale P7a-era "latency numbers are coarse/experimental" claim
(superseded by P7b's trustworthy probe) — a single-rep drift note, not a graded fact miss.

**V3 (V1 minus the inoculation list): 6/8 — T1 (retries) regressed to 0/2.** The ablation's cleanest
signal: without the refutations block, rep1 opened "Good instinct — and in fact it's already there …
there's nothing to add" (endorsement — hard FAIL) and rep2 recommended "keep the current posture (one
retry layer)" without ever stating the ban or the 36/5/1 flaky-pass measurement (hedged — FAIL under the
conservative rule). T2/T3/T4 passed 2/2 each because their refutations have strong secondary homes the
runs actually routed to: the forensics docs' fates tables (T2 reps quoted the disassembly-level `cmp/b.eq`
evidence), the validator agent file's TURN-ALIVE INVARIANT, and — one rep — an explicit disk `Read` of the
main project's memory file (found by search; not context injection — each variant worktree got its own
fresh project dir, so auto-memory was absent from every variant's context and parity held).

## Dose-response table (design D7/D8, final)

| Variant | AGENTS.md chars | Startup tokens | Rule | Recall | Trap |
| --- | --- | --- | --- | --- | --- |
| V0 fat | 79,704 | 57,137 | 10/12 (R1 1/3) | 12/12 | 12/12 |
| **V1 slim (ships)** | 28,132 | 35,589 (−21,548) | **12/12** | 12/12 | 12/12 |
| V2 −tables | 25,346 | 34,252 (tables ~1,320) | n/r | 8/8 | 8/8 |
| V3 −inoculations | 27,150 | 35,126 (inoculations ~463) | n/r | n/r | **6/8 (T1 0/2)** |

## D7 content decisions

1. **The retries inoculation line is measured load-bearing** (V1 3/3 → V3 0/2; ~40 tokens standing
   between "banned, here's the measurement" and "good instinct, nothing to add"). Kept — no edit needed,
   it already ships in V1.
2. **T2/T3/T4 lines kept despite passing without them**: their doc-homes carried these probes, but the
   T1 regression demonstrates the failure mode for any refutation whose home is thinner, the total cost
   of all 11 lines is ~463 tokens, and the probe set is a sample (design risk register). No line dropped.
3. **No new inoculation lines promoted** — V1 failed no trap.
4. **Status tables kept on orientation grounds** (~1,320 tokens): the probe set cannot price their unique
   content (recorded as a probe-set gap rather than paper evidence either way).
