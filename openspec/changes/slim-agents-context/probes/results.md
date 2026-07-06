# Probe results — slim-agents-context

Grading per `README.md` rubric. V0 graded and **frozen 2026-07-06 before any V1 run** (design D6).
Full run JSONs: `~/Downloads/xtty-vm-poc/artifacts/2026-07-06-slim-agents-probes/`.

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

## V1 (slim) — pending
## Ablation arms (V2 recall+trap, V3 trap) — pending
