# Tasks — harden-validator-delegation-trigger

## 1. AGENTS.md — boundary, marker convention, self-check

- [ ] 1.1 In the test-validation rule (AGENTS.md → How to work here), add the **iterate-vs-validate boundary** (design D1/D4): inline is expected for cheap iterative feedback (`make test-core`, one-off `-UITestGridDump` launches, greps, `make doctor`, `openspec validate`, `gh run watch`); the agent is required for the **Tier‑1 XCUITest suite (`make test`), any VM tier, or a full acceptance matrix**. State `make bench` is inline-permitted on its own but rides with a full-matrix task's delegation.
- [ ] 1.2 In the same rule, introduce the **per-task delegation marker** `⟶ xtty-test-validator (<tier/scope>)` — required on delegate-set verify tasks — and the **pre-tick self-check** (design D7): before ticking a verify task that ran a suite, the counts must come from a validator report, or the inline run must be a cheap/iteration case within the boundary. Keep AGENTS.md the single source of the boundary definition.
- [ ] 1.3 In the "keeping a change coherent" task-authoring guidance (AGENTS.md → OpenSpec workflow), add a checklist item: suite-executing verify tasks (Tier‑1 / VM / full matrix) MUST be authored with the delegation marker.
- [ ] 1.4 Verify: `AGENTS.md` states the boundary, the marker, and the self-check in one place, and the "keeping a change coherent" checklist references the marker; a `grep -n "xtty-test-validator (" AGENTS.md` shows the marker convention documented.

## 2. config.yaml — seed the marker at propose time

- [ ] 2.1 Populate `openspec/config.yaml` `rules.tasks` (currently commented/empty) with a **short pointer** instructing that suite-executing verify tasks (Tier‑1 / VM / full matrix) be authored with `⟶ xtty-test-validator (<tier>)`, **deferring to AGENTS.md → test-validation for the boundary** (a pointer, not a restatement — design D2).
- [ ] 2.2 Verify by effect: `openspec instructions tasks --change <any-change> --json` includes the populated `rules.tasks` entry (the probe this change ran confirmed a populated `rules.tasks` surfaces). If a future CLI omits `rules`, fall back to the compact equivalent in `config.yaml`'s `context` block (proven to flow) and note the fallback inline.

## 3. test-validation spec delta

- [ ] 3.1 Confirm `specs/test-validation/spec.md` MODIFIES "Two documented spawn scenarios" with the boundary + marker + self-check text and the three added scenarios (marker-authored task, cheap-check-inline, documented boundary), pasted from the current established requirement with only this change's edits applied.
- [ ] 3.2 Verify: `openspec validate "harden-validator-delegation-trigger"` passes.

## 4. Retrofit the open changes (make the fix live now — design D5)

- [ ] 4.1 `harden-churn-shell-readiness/tasks.md`: add the `⟶ xtty-test-validator (<tier>)` marker to its suite-executing verify tasks only (Tier‑1 `make test` / VM / full-matrix); leave cheap checks unmarked. No scope or requirement change.
- [ ] 4.2 `add-xtty-test-image/tasks.md`: same retrofit — mark only the verify tasks that run a VM tier or the in-guest suite; leave cheap checks unmarked.
- [ ] 4.3 `add-ci-pipeline/tasks.md`: same retrofit — mark only suite-executing verify tasks (if any remain unchecked); leave cheap checks unmarked.
- [ ] 4.4 Verify: each retrofitted change still validates (`openspec validate <name>`), and a `grep -n "xtty-test-validator (" openspec/changes/*/tasks.md` shows markers only on Tier‑1/VM/full-matrix tasks, none on cheap checks.

## 5. Final validation

- [ ] 5.1 `openspec validate "harden-validator-delegation-trigger"` passes; `openspec validate --all --type spec` unaffected.
- [ ] 5.2 Out of scope, stated for the record: editing the generic `/opsx:apply` / `/opsx:propose` skills (not ours; the `tasks.md` marker is the reaching mechanism); a hard apply-side delegation gate (deferred pending the §6 outcome); an optional headless behavioral probe (the by-effect proof on the real next apply supersedes it). **Explicitly NOT added:** a gratuitous marked/validation task inside *this* change — it is docs-only (nothing to validate), and marking a task solely to trigger the agent would violate the D1 boundary this change establishes (mark only genuine Tier‑1/VM/matrix tasks). The proof lives where a sweep is genuinely warranted (§6).

## 6. Proof by effect — HOLD-OPEN (the real bar; design D6)

> This change is **implemented-but-open** until §6 is captured — the repo's "left open pending live validation" pattern (cf. `add-ci-pipeline` first CI run, `add-test-validation-agent` live-smoke). The proof executes during a *different* change's apply, so it cannot be ticked in this apply session.

- [ ] 6.1 **Sequencing (must hold, or the proof is void):** this change is applied **first** (its §1–§4 put the markers in AGENTS.md + config.yaml and retrofit `harden-churn-shell-readiness`'s suite-executing verify tasks). *Then* the context is **compacted**. *Then* `harden-churn-shell-readiness` is applied. The markers only exist post-apply of this change, so applying `harden-churn-shell-readiness` first would test nothing.
- [ ] 6.2 **Pass criterion (capture verbatim here when it happens):** on the post-compact `harden-churn-shell-readiness` apply, its marked validation verify task triggers an **autonomous** `xtty-test-validator` spawn — the session delegates *without the user asking* and ticks the task from the report's verbatim counts. `harden-churn-shell-readiness` is genuine product code that needs the sweep anyway, so this is a real trigger, not a staged one. Record the outcome as one of: **autonomous-spawn** (proof holds) / **prompted** (needed a nudge — partial) / **inlined-anyway** (proof fails). Then tick this and archive.
- [ ] 6.3 **Primed-observer caveat (proof hygiene):** do **not** count this change's *own* apply as the proof — that session just authored the marker convention, so it is maximally primed; delegating there proves the machinery, not unprimed adherence. The cleaner the compaction at 6.1 (the less its summary foregrounds "we are testing delegation"), the stronger the proof; note in the capture how primed the post-compact context was.
- [ ] 6.4 **Negative-result protocol:** if 6.2 is **inlined-anyway**, do NOT silently patch it — that is exactly the measured evidence justifying a **stronger apply-side gate**. Capture it, leave this change's finding recorded, and open a follow-up change for the harder mechanism. A marker that fails under a fresh context is a result, not a bug to hide.
