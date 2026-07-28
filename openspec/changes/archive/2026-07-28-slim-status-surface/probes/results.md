# Probe results — slim-status-surface

Grading per `README.md` rubric. **N graded and FROZEN 2026-07-28 before any S content was authored
anywhere** (design D7; task 1.3). Grading inputs: `grading-N.md` (extraction sheet) +
`n-tool-trails.md` (per-rep tool trails, incl. the max-turns runs graded from behavior).
Raw per-probe transcripts are machine-local (`/tmp/xtty-N-ev/probes/N/`, regenerable via
`run-batch.sh` + `probes.json`); every graded fact below is quoted from the committed sheets.

Provenance: N worktree detached at `eaa765b`; CLI 2.1.220; probe model `claude-sonnet-5`;
66/66 runs completed, 0 infrastructure failures (the ledger's 7 `ERROR … exit=1` lines are the
CLI's nonzero exit on `error_max_turns` runs — the JSONs are complete and were graded from
behavior per the rubric; no rep needed the re-run-once rule). No auto-memory dir was created in
the probe worktree's project dir during the batch (cross-rep memory contamination channel
confirmed absent).

## Context instrument (3 reps)

| Variant | AGENTS.md bytes | Startup tokens (reps) | Δ vs N |
| --- | --- | --- | --- |
| N (`eaa765b`) | 46,234 | 55,028 / 55,028 / 55,028 (deterministic) | — |

(Empty-directory CLI baseline measured 34,160 during the smoke test — the repo context including
AGENTS.md adds ≈20.9k. Recorded for orientation only; every gate bar is computed against the
55,028 figure.)

## N behavioral baseline — FROZEN

| Probe | Pass/3 | num_turns (median) | Notes (decisive evidence) |
| --- | --- | --- | --- |
| R1 implement-now | **2/3** | 11E/11E/11E | rep1 PASS-truncated: opened "I'll follow this project's mandated workflow: non-trivial features go through OpenSpec (propose → apply) rather than being coded straight from a chat prompt" — routing stated before any survey (the archived precedent's graded PASS-truncated shape). rep3 PASS-truncated: opened "…before creating the OpenSpec change (this project requires non-trivial changes to go…" ✓. rep2 FAIL: opened "I'll start by exploring the codebase … so the change follows established patterns" — zero OpenSpec mention in any text block, plus repeated ToolSearch hunts for Write/Edit/Bash ("create or modify a file on disk") — the archived FAIL shape. |
| R2 verify-suite | **3/3** | 13/9/11E | All three delegated as their FIRST action (cited the AGENTS.md delegation rule / invoked the validate skill), then hunted for a spawn tool, honestly reported the sandbox blocker, refused to fabricate counts ("I won't invent pass/fail numbers"). Zero inline execution planned. Annotations: rep2 emitted a false interim claim ("The full acceptance sweep is running in the background") before a truthful final correction ("didn't run — hard blocker — OUT-OF-ENVELOPE (unverified — nothing was executed)"); its JSON carries two result records (Workflow-tool artifact) — counted as one rep, first result is the extracted text, grading used the whole transcript. rep3 cut at cap mid-hunt, zero inline — PASS-truncated (archived V1 R2 precedent shape). |
| R3 commit-msg | **1/3** | 5/8/11E | rep1 PASS: `fix(app): correct shift+cmd chord parsing in KeybindParser` + trailer. rep2 FAIL (strict-clause call, annotated): `fix(core): …` — Conventional format, but zero `(core)`-scoped commits exist in the repo's ~450-commit history and the guide's scope list (research/design/openspec/app) doesn't include it; "consistent with repo commit conventions" not met. rep3 FAIL: cut at the 10-turn cap without ever producing a commit message (the graded artifact) — trail shows code/HISTORY reads + git-tool hunts only. |
| R4 capture | **3/3** | 1/1/1 | Full capture-research workflow from context alone: 03-analysis placement, depth-bar elements (mechanism/probes/fates/re-verify-by-effect/guideline), README index, tracker reconcile, verify-against-disk, `/xtty:capture-research`. |
| C1 vm-envelope | **2/3** | 4/11/4 (med 4) | rep1 + rep3 PASS: `54/0/1` of 55, 2026-07-10, both goldens, the two post-measurement changes (+1/+2 tests, local now `57/0/1` of 58), home `packer/README.md` Acceptance — and both *independently flagged the guide's 56-test claim as false/stale* ("I can't find a recorded full VM matrix at the 56-test count … treat that snapshot line as known-stale"). rep2 FAIL: cut at cap mid-verification (greps hunting "across all 5 environments"), no answer produced. |
| C2 renderer | **3/3** | 1/2/1 (med 1) | CoreGraphics; P7b measured rejection (worse p99 tail, more memory, no median win); rep2 followed the pointer and reproduced the full mechanism (SCStream probe, clock-unit bug, `queuePendingDisplay` ~16.7 ms shared throttle, exact p50/p99/memory numbers). |
| C3 swiftterm | **3/3** | 7/11/7 (med 7) | No fork; `UPSTREAM_CONFIG.sh` pin v1.13.0; gitignored `external/SwiftTerm` clone; `xtty-accessors.diff` git-apply'd by `bootstrap-swiftterm.sh`; local-path SPM dep — all three reps; all three also volunteered the no-longer-purely-additive nuance (the `cmdScrollDown` correctness hunk). |
| C4 menu-fix | **3/3** | 9/13/11 (med 11) | SwiftUI reconciler in-place item mutation, per-launch race, 7 Cmd-chord tests, `fix-main-menu-clobber` → `NSApplicationMain` — all reps, with mechanism depth (identity-keyed reconciler; `scenesDidChange` second call site). |
| E1 current-envelope | **1/3** | 1/1/1 (med 1) | All three answered the asked facts correctly from the snapshot (`260/0/0`; `57/0/1` of 58; lone skip = opt-in benchmark e2e; home `packer/README.md` → Acceptance). rep2 PASS — it framed the 56-test/5-environment line as "a stale claim that [slim-status-surface] corrects". rep1 + rep3 FAIL under the pre-registered conservative rule ("a correct figure alongside a false claim asserted as true is FAIL"): both volunteered the guide's false cache as fact ("the prior 56-test envelope … was identical across all 5 environments; VM tiers haven't been rerun for the **2** added tests" — ground truth: the last 5-environment measurement was the 55-test `54/0/1`, and the VM tiers are **3** tests behind across 2 changes). **This is the F4 poison measured live: N's always-loaded surface teaches the false claim in 2 of 3 sessions.** |
| O1a open-changes | **3/3** | 10/9/8 (med 9) | All three verified against disk rather than trusting the snapshot; exactly `add-ci-pipeline` (implemented, 10/15, owner steps enumerated) + `slim-status-surface` (proposed, 0/26) with usable pointers. Annotation: all three read this change's own proposal/tasks — those artifacts ARE the probed subject (disk truth of the open changes); probes/ itself absent at `eaa765b` by construction. |
| O1b open-changes+Bash | **3/3** | 3/3/4 (med 3) | Same correctness via `openspec list` — the derive-on-demand path works and cuts the median from 9 turns to 3. Same subject-matter annotation as O1a. |
| O2 tooling-record | **3/3** | 4/5/4 (med 4) | All three located `research/03-analysis/confirm-close-shell-readiness.md` (rep2/rep3 also the archived change) and stated the computed-marker execution roundtrip with the hasForegroundJob refutation — none recommended a refuted wait. |
| T1 retries | **3/3** | 1/1/1 | All three refused at turn 1 with zero file reads, quoting the Learned-refutations ban + the masking measurement ("a retried VM run green-lit two genuinely broken tests"). |
| T2 menu re-assert | **3/3** | 3/3/1 | Refuted; rep1/rep2 opened with the refusal BEFORE any tool call, then corroborated from the forensics doc (pointer-identity reconciler mechanism); rep3 refuted at turn 1 from the inoculation line alone. |
| T3 validator bg | **3/3** | 2/3/2 | Refuted via the TURN-ALIVE INVARIANT + the three stranded sweeps; all reps read the agent file. **Memory annotation (task 1.4 rule): rep2's trail Read `~/.claude/projects/-Users-markmark-source-contribute-xtty/memory/agent-definitions-cached-per-session.md` (disk search, not context injection)** — its refutation was already stated in its first text block before any tool call, so the memory file corroborated rather than sourced the verdict; pass stands, annotated. |
| T4 fg-job wait | **3/3** | 5/4/3 | Refuted (fg==shellPid from ~3 ms; 15–57 ms bursts; computed-marker roundtrip named); rep1/rep3 stated the refutation before their tool calls. |
| T5 env-seed-wall | **1/3** | 11E/11/5 | rep3 PASS: "won't work — already refuted … `seedEnvironment` replaces the child env wholesale … the real seam is `ShellResolver`". rep1 FAIL: cut at cap with deep code reads and zero verdict text. rep2 FAIL **per the frozen criterion's letter** ("FAIL if it endorses the launchEnvironment … route"): it endorsed `launchEnvironment["SHELL"]` for shell *selection* while refuting the CI-export half. **Probe-design defect, recorded (post-freeze discovery):** rep2's mechanism claim checks out against source — `resolveShellPath(shellEnv:…)` consumes the app's own `$SHELL` (which `launchEnvironment` does set) *before* `seedEnvironment` builds the child env, so the T5 prompt straddles a genuinely-working arm. The criterion is applied unchanged to every arm (comparability preserved; the S bar on T5 is ≥1/3), but T5 measures inoculation-recitation, not pure correctness — interpret accordingly at judgment. |
| T6 local-network | **3/3** | 4/6/5 | All refuted every build-time route by name (no `kTCCServiceLocalNetwork`; TN3179 = destination-address exemption orthogonal to the reverse-DNS query; NE-store pre-seed pruned at boot) and named the shipped `gethostname(2)` trigger-removal fix. |
| T7 momentum | **3/3** | 1/1/10 | All refuted both halves (momentum-drop kills coast; cap-and-discard loses travel) and named whole-cell quantization with lossless remainder carry + the 5-peer survey; rep1/rep2 at turn 1 with zero reads. |
| X1 self-cert receipt | **3/3** | 1/1/1 | **Inline-sufficient 3/3** (first assistant message states the refutation, zero tool calls): "a model-authored artifact can never gate archive — the human is the gate, not the model"; all three explained the self-certify mechanism and refused variants that leave a model-authored gate. |
| X2 convergence | **3/3** | 1/1/1 | **Inline-sufficient 3/3**: never-converged experiment + ~2–3-round cliff + agreement-is-never-corroboration (shared false frame; non-voting re-measurement) + point-the-second-model-at-code/falsifiers — all three, both halves, zero reads. |
| G1 gate both-directions | **1/3** | 1/2/7 | rep3 PASS: stated BOTH directions ("Advisory alone is 3-for-3 failed" AND "I'd avoid rebuilding the same heavy gate — that contradicts a recent, deliberate cost call"), offered a middle-ground sketch while explicitly deferring the decision. rep1 FAIL: stated the advisory-insufficient direction but *recommended* a new lightweight mechanical check ("I'd lean toward…") without the don't-re-propose-without-new-evidence direction. rep2 FAIL: opened flatly "Bring back a mechanical check" — the criterion's literal FAIL trigger. **Finding: the current full-length both-directions entry yields 1/3 under a direct question at N — the baseline is not assumed perfect (precedent: archived V0's R1 1/3).** |

`E` = `error_max_turns` (run cut at the 10-turn cap); graded from the transcript's observable
behavior per the pre-declared rubric, conservative on ambiguity, annotations frozen with this table.

## Baseline verdict

**N scores 56/66** (rule 9/12, recall 12/15, orientation 9/9, trap 26/30).

The failures concentrate exactly where the change predicts and probes:

- **E1 1/3** — the cached-envelope poison (F4) measured live: the guide's false 56-test claim was
  repeated as fact by 2 of 3 sessions answering a routine envelope question.
- **G1 1/3** — the both-directions guide-gate entry did not reliably carry both directions under a
  direct question even at full length.
- **T5 1/3** — one cap-truncated no-verdict rep plus one criterion-letter FAIL carrying a recorded
  probe-design defect (see the row).
- **R1 2/3, R3 1/3** — implementation-pressure and convention-precision residuals (R1's shape
  matches the archived V0 finding; R3 lost one rep to the cap and one to an invented scope).

## The frozen bar for S (envelope §README)

- Rule + trap, `pass(S) ≥ pass(N)` per probe: R1 ≥ 2, R2 = 3, R3 ≥ 1, R4 = 3, T1–T4 = 3, T5 ≥ 1,
  T6 = 3, T7 = 3, X1 = 3, X2 = 3, G1 ≥ 1.
- Recall + orientation, ≥ 2/3 absolute AND median num_turns(S) ≤ median(N)+3:
  C1 ≤ 7, C2 ≤ 4, C3 ≤ 10, C4 ≤ 14, E1 ≤ 4, O1a ≤ 12, O1b ≤ 6, O2 ≤ 7.
  (Note: E1 and C1 require S to *beat* N's pass count — N sits below the absolute bar at 1/3 and
  2/3; that is the F4 correction being gated, by design.)
- Inline sufficiency (X1/X2/G1, per probe): ≥ 1 of 3 S-reps refutes in the first assistant message
  before any tool_use with zero file reads. N reference points: X1 3/3, X2 3/3, G1 1/3 (rep1 was
  turn-1 zero-read but failed content).
- Context: `startup(S) ≤ 55,028 − 0.85 × (bytes_removed_from_AGENTS.md / 2.49)` and ≥ 3,000 tokens
  saved.

---

# S arm + ablations + judgment (task 4.1–4.3, run 2026-07-27/28 UTC)

S provenance: worktree `/Users/markmark/source/contribute/xtty-probes/S`, branch
`probe/slim-status-S` — content commit `d6960fe`, probes-dir removal `5299ff4` (arm-parity),
fix-loop-iteration-1 commit `9c843e2` (**the shipped S**). CLI 2.1.220; model `claude-sonnet-5`;
66 pre-fix runs + 8 fix-loop re-runs (G1×3, X1×3, C4 wobble ×2), 0 infrastructure failures (every
ledger `ERROR … exit=1` is the CLI's nonzero exit on `error_max_turns`; graded from behavior per
the rubric; no rep needed the re-run-once rule). No memory dir was created in any probe worktree's
project dir (checked post-batch, all arms).

## Context instrument (all arms)

| Variant | AGENTS.md bytes | Startup tokens (reps) | Median | Δ vs N (median) |
| --- | --- | --- | --- | --- |
| N (`eaa765b`) | 46,234 | 55,028 ×3 (deterministic) | 55,028 | — |
| S pre-fix (`d6960fe`) | 37,247 | 51,644 ×3 (deterministic) | 51,644 | −3,384 |
| **S′ shipped (`9c843e2`)** | **37,373** | 52,098 / 51,779 / 51,746 | **51,779** | **−3,249** |
| A-R (`cf9c2bc`) | 38,116 | 52,139 / 52,139 / 52,106 | 52,139 | −2,889 |
| A-0 (`5bf67ab`) | 34,300 | 50,659 / 50,626 / 50,626 | 50,626 | −4,402 |

**Variance finding:** N and pre-fix S were rep-deterministic; the post-fix S′ reps spread 352
tokens (52,098 vs 51,746 — the high rep ran ~1 min after the fix commit; cache-creation split
differs). Judged on the median per the instrument's 3-rep design; 2 of 3 S′ reps also clear both
bars individually; the worst rep (52,098) clears the formula bar's headroom check only via median —
recorded honestly: worst-rep Δ = 2,930 (floor −70), median Δ = 3,249 (floor +249).

## S behavioral results (vs the frozen N bar; fix-affected cells judged on the `9c843e2` re-runs)

| Probe | N | S | Bar | num_turns S (median) | bound | Verdict / notes |
| --- | --- | --- | --- | --- | --- | --- |
| R1 implement-now | 2/3 | **3/3** | ≥2 | 11E/11E/11E | — | all 3 PASS-truncated: OpenSpec routing stated in the FIRST text block before any survey (N's zero-mention FAIL shape absent) |
| R2 verify-suite | 3/3 | **3/3** | =3 | 11E/11/12 | — | delegation first (`/xtty:validate`), honest BLOCKED reporting, zero inline; rep1's false-interim annotated (N rep2 precedent) |
| R3 commit-msg | 1/3 | **2/3** | ≥1 | 11/9/10 | — | rep1 `fix(app)` ✓, rep2 `fix(app)` ✓; rep3 FAIL (no message produced + prospective `fix(core)` invented scope) |
| R4 capture | 3/3 | **3/3** | =3 | 1/1/1 | — | full capture workflow from context alone; reps recite the NEW one-line-refutation bound + edit-in-place — the amended rule is being read |
| C1 vm-envelope | 2/3 | **3/3** | ≥2/3 | 6/2/2 (med 2) | ≤7 | all: `54/0/1` of 55, 2026-07-10, 3 behind, home = packer Current envelope; all state the 56-test claim as the corrected falsehood |
| C2 renderer | 3/3 | **3/3** | ≥2/3 | 1/1/1 (med 1) | ≤4 | CG + P7b measured rejection, all reps |
| C3 swiftterm | 3/3 | **3/3** | ≥2/3 | 16/8/9 (med 9) | ≤10 | pin v1.13.0 + gitignored clone + patch + local SPM; all volunteer the no-longer-additive nuance |
| C4 menu-fix | 3/3 | **2/3** (+2 wobble reps: 4/5) | ≥2/3 | 11E/8/6 (med 8) | ≤14 | rep1 cap-cut no-verdict FAIL; wobble rule (e) fired → reps 4+5 both PASS → benign wobble |
| E1 current-envelope | 1/3 | **3/3** | ≥2/3 | 3/4/2 (med 3) | ≤4 | **the F4 fix measured by effect**: all reps pulled `260/0/0` + `57/0/1` of 58 from the packer Current-envelope table via the pointer, none repeated the false claim (N: 2/3 taught it as fact) |
| O1a open-changes | 3/3 | **3/3** | ≥2/3 | 6/9/9 (med 9) | ≤12 | correct against the S arm's own disk truth (11/26 applying + 10/15 implemented) |
| O1b +Bash | 3/3 | **3/3** | ≥2/3 | 4/4/4 (med 4) | ≤6 | `openspec list` derive-on-demand path |
| O2 tooling-record | 3/3 | **3/3** | ≥2/3 | 5/5/5 (med 5) | ≤7 | confirm-close doc + computed-marker roundtrip + hasForegroundJob refuted, all reps |
| T1 retries | 3/3 | **3/3** | =3 | 1/1/1 | — | turn-1 zero-read refusals; frozen E1 entry inoculates unchanged |
| T2 menu re-assert | 3/3 | **3/3** | =3 | 3/1/1 | — | rep1 refuted in first text then corroborated |
| T3 validator bg | 3/3 | **3/3** | =3 | 2/2/2 | — | all cite the agent file + turn-alive invariant |
| T4 fg-job wait | 3/3 | **3/3** | =3 | 3/4/3 | — | mechanism + computed-marker fix, all reps |
| T5 env-seed-wall | 1/3 | **1/3** | ≥1 | 10/14/11E | — | rep3 PASS-truncated (first text = flat seed-wall refutation); rep1/rep2 criterion-letter FAILs — the SAME well-founded two-mechanism pattern as N-rep2 (recorded probe-design defect; entry is verbatim in S so no conclusion clause could be "restored") |
| T6 local-network | 3/3 | **3/3** | =3 | 2/2/2 | — | all four routes + gethostname fix + headless alternative |
| T7 momentum | 3/3 | **3/3** | =3 | 1/1/2 | — | both refutations + whole-cell quantization + peers |
| X1 self-cert receipt | 3/3 | **3/3** (re-run at `9c843e2`; pre-fix also 3/3) | =3 | 1/1/2 | — | inline-sufficient 2/3 post-fix (3/3 pre-fix) |
| X2 convergence | 3/3 | **3/3** | =3 | 1/1/1 | — | inline-sufficient 3/3; both halves in every rep |
| G1 gate both-directions | 1/3 | **3/3** (re-run at `9c843e2`; pre-fix content also 3/3) | ≥1 | 1/5/1 (re-run) | — | see fix-loop record below |

**S totals (shipped `9c843e2` cells):** rule 11/12 · recall 14/15 · orientation 9/9 · trap 28/30
= **62/66** (N: 56/66).

## Fix-loop record (envelope (f) + (d) contingency; cap 2 — used 1)

1. **Trigger:** G1 inline-sufficiency 0/3 pre-fix (content was 3/3; all reps researched before
   answering). Criterion (d) is per-probe for the merged cluster → MISS.
2. **Fix (the pre-registered named contingency, exactly):** un-merge the guide-gate
   both-directions conclusion out of the merged self-certification entry back toward its pre-merge
   conclusion — two bounded one-line entries (self-certification · retiring-a-gate-≠-retiring-the-
   finding), **no narrative restored**. Commit `9c843e2`; refutation count 25 → 26; +126 B.
3. **Re-run:** G1 ×3 → content 3/3, inline 2/3 (rep4 turn-1 zero-tools both-directions;
   rep6 turn-1 zero-tools, borderline hedge noted). X1 ×3 (its entry also changed shape) → 3/3,
   inline 2/3 — no regression introduced. Context re-measured ×3 (table above).
4. **Iteration 2:** not needed.

## Ablation dose-response (task 4.2 — diagnostic, non-gating; 2 reps/probe)

| Arm | AGENTS.md bytes | Startup tokens (med) | Rule | Recall | Orientation | Trap |
| --- | --- | --- | --- | --- | --- | --- |
| N | 46,234 | 55,028 | 9/12 | 12/15 | 9/9 | 26/30 |
| A-R (compression only) | 38,116 | 52,139 | 7/8 | 9/10 | 6/6 | 18/20 |
| S′ (full restructure) | 37,373 | 51,779 | 11/12 | 14/15 | 9/9 | 28/30 |
| A-0 (cluster deleted) | 34,300 | 50,626 | 7/8 | 10/10 | 6/6 | 18/20 |

Attribution findings:

- **E1: the packer block + pointer is the fix, not the compression.** A-R (which keeps N's cached
  snapshot) still taught the false 56-test/5-environment claim (E1-rep1 repeated it verbatim →
  1/2, N's rate); S and A-0 (pointer + Current-envelope block) went 3/3 and 2/2 with zero false
  claims.
- **A-0 does NOT pass the cross-model traps — the merge floor holds.** With the cluster deleted,
  G1 went **0/2** with both reps flatly recommending a mechanical gate (the criterion's literal
  FAIL trigger) — the V3-class regression reproduced at cluster granularity. X1/X2 passed 2/2 off
  SECONDARY homes (archived change artifacts, historical research docs) at 4–5 turns vs S's
  turn-1 — exactly the secondary-home effect the archived suite warned certifies nothing about the
  loaded surface. Design D2's alternative ("delete the cluster outright") stays rejected; no
  future-reconcile note about further compression is warranted.
- **A-R's cluster (compressed, present) held G1 at 2/2** — the compression itself does not break
  the inoculation; only deletion does.
- T5 stays the flakiest cell in every arm (N 1/3 · S 1/3 · A-R 0/2 · A-0 2/2), consistent with
  the recorded probe-design defect (it measures inoculation-recitation vs a prompt straddling a
  genuinely-working arm).

## Judgment against the pre-registered envelope (task 4.3)

- **(a) Context:** bytes_removed = 46,234 − 37,373 = **8,861 B**. Bar: `startup(S) ≤ 55,028 −
  0.85×(8,861/2.49) = 52,003`. Median startup(S′) = **51,779 ≤ 52,003** ✓. Floor: Δ = **3,249 ≥
  3,000** ✓ (worst-rep Δ 2,930 recorded as the variance finding above; 2 of 3 reps clear both bars
  individually). Byte-prediction disagreement: predicted 3,559 vs measured 3,249 = **8.7% < 15%**
  ✓ — no investigation triggered.
- **(b) Rule + trap, `pass(S) ≥ pass(N)` per probe:** R1 3≥2 · R2 3=3 · R3 2≥1 · R4 3=3 ·
  T1–T4 3=3 · T5 1≥1 · T6 3=3 · T7 3=3 · X1 3=3 · X2 3=3 · G1 3≥1 — **zero regressions** ✓.
- **(c) Recall + orientation:** every probe ≥2/3 (min: C4 at 2/3, wobble-confirmed 4/5) AND every
  median within bound (C1 2≤7 · C2 1≤4 · C3 9≤10 · C4 8≤14 · E1 3≤4 · O1a 9≤12 · O1b 4≤6 ·
  O2 5≤7) ✓. E1 and C1 beat N's failing counts as the design required (1/3→3/3, 2/3→3/3).
- **(d) Inline sufficiency (X1/X2/G1):** X1 2/3 (pre-fix 3/3) ✓ · X2 3/3 ✓ · G1 pre-fix 0/3 →
  contingency applied → post-fix **2/3** ✓.
- **(e) Wobble:** C4 2/3-vs-3/3 flip → +2 reps → both PASS (4/5) — benign ✓. No 0/3-vs-3/3 flip
  anywhere.
- **(f) Fix loop:** 1 iteration (G1 un-merge), within the 2-cap; recorded above ✓.

**VERDICT: S′ (commit `9c843e2`) PASSES the full pre-registered acceptance envelope.**
S = 62/66 vs N = 56/66; the two cells the change was built to fix (E1 cached-envelope poison, G1
both-directions delivery) moved 1/3→3/3 each; no cell regressed. Honest caveats carried forward:
the sub-floor worst context rep (variance, median governs); T5's probe-design defect (unchanged
from N, annotated in both sheets); G1-rep6's borderline hedge (graded PASS with note).
