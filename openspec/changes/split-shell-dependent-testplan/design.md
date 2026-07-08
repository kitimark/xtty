## Context

The second half of the two-change plan (`research/03-analysis/shell-dependent-test-partitioning.md`). `add-zsh-test-image` built the zsh rig and measured the divergence; this change restructures the suite so the divergence is handled honestly. Today the shell-dependent half is dishonest on the bash rig: the 19-method semantic-capture family early-returns before asserting (a `guard waitForSemanticCaptureActive() else { …; return }` degrade arm → vacuous pass), and `testMultiLinePasteIsNotAutoExecuted` (`AppUITests/XttyUITests.swift:62`) asserts unconditionally and hard-fails on bash 3.2's missing bracketed paste. SwiftTerm's paste path already brackets correctly when `terminal.bracketedPasteMode` is true (`MacTerminalView.swift:1180`); the flag is `public private(set)` and readable by the DEBUG dump. Nothing about the *product* is wrong — only the test suite conflates "the shell can't do this" with "pass" or "fail."

There are two ways to make it honest. **(Original) skip-and-partition:** each shell-dependent test *skips* where its capability is absent, and the suite splits into two `.xctestplan`s so a rig can select the set it can honor. **(This change, pivoted) parameterize-and-assert:** each shell-dependent test *asserts the correct behavior for the observed capability* — a skip is a coverage hole (it verifies nothing on that shell), and the shell behaviors are already measured, so a per-shell assertion is strictly more informative and catches regressions on **both** shells. This change adopts the second. The pivot's rationale was worked through in explore (2026-07-08); the paste test is the exemplar.

## Goals / Non-Goals

**Goals:**
- Every shell-dependent test asserts the behavior expected for the terminal's **observed** capability, on **every** rig — no vacuous pass, no capability red, and no coverage hole where a skip used to sit.
- The paste test reads the true predicate (`bracketedPasteMode`) from the state dump (sampled after readiness) and asserts per-shell: staged (bracketed) vs forwarded line-by-line (not).
- A skip survives only as a **last resort**, where the capability-absent case admits no meaningful assertion.
- The zsh rig becomes a standing validator environment carrying the capability-present arm.

**Non-Goals:**
- No product/app behavior change (paste bracketing + OSC injection already correct).
- **No terminal-level multi-line-paste guard** (a "confirm paste with newlines" feature, à la iTerm2) — that is a future *layer-3* product feature (D2); this change asserts xtty's *current forwarding fidelity*, not a paste-safety guarantee on non-bracketed shells.
- No new shell beyond bash/zsh; no GitHub-Actions zsh job; no change to `make test`'s default (still the whole suite).

## Decisions

### D1 — Parameterize by observed capability; do NOT partition into test plans (replaces the original D1 + D2)

Each shell-dependent test branches on the terminal's **observed** capability and asserts the behavior expected in that state, rather than skipping on the "wrong" shell. Consequence: **there is nothing to skip-around, so the two-`.xctestplan` partition is dropped.** The full suite runs on every rig; the bash rig takes each test's capability-absent arm (assert, or last-resort skip), the zsh rig its capability-present arm.

**Why drop the partition:** its entire purpose was to let a rig/CI *select the set it can honor* so skips wouldn't pollute the count. With per-shell assertions there are (near-)zero skips, so no selection is needed — removing `Intersection.xctestplan` + `ShellInteractive.xctestplan`, the `project.yml` scheme `testPlans:` wiring, and the XcodeGen-fidelity risk (the original Open-Question Q1 **dissolves**). The few last-resort skips (D4) surface on the **non-blocking** `build-and-test` job; the required gate is `test-core` (view-free units), unaffected — so honest skips there cost nothing.

*Alternative rejected:* keep both plans **and** parameterize — redundant machinery for a selection no longer needed.

### D2 — The paste test is the exemplar: assert forwarding fidelity per shell (not a paste-safety value)

Model the paste through three layers:

```
layer 1  what the SHELL does     bash 3.2: ⏎ = execute    zsh: bracketed = stage   ← shell-owned, stable
layer 2  what xtty does          forward the paste faithfully to the PTY            ← WHAT THIS TEST ASSERTS
layer 3  what xtty COULD do      terminal-level "confirm multi-line paste" guard    ← UNBUILT feature (Non-Goal)
```

At **layer 2 xtty is correct on both shells** — it forwards faithfully; the shell's capability decides the outcome. So parameterizing does **not** bless a bug; it asserts *forwarding fidelity*. The footgun (auto-executing pasted commands) lives at layer 3 — an absent guard — which is a separate feature+test, not this one.

**The precise bash behavior** (payload `"alpha<tag>\nbeta<tag>"`, **no trailing newline**): readline treats each `\n` as accept-line, so `alpha<tag>⏎` **executes** (→ `bash: alpha<tag>: command not found`) while `beta<tag>` (no trailing `⏎`) stays **staged** at the next prompt. So the assertion is not "every line executes" — it is "the newline-terminated line executes, the unterminated tail stages." The current `:87` check simply **inverts by shell**:

| Assertion | zsh (bracketed) | bash 3.2 (no bracketed) |
| --- | --- | --- |
| `alpha<tag>` present | ✅ (staged) | ✅ (echoed executed cmd) |
| `beta<tag>` present | ✅ (staged) | ✅ (staged at next prompt) |
| `"command not found"` present | ❌ absent | ✅ present |

This is **already measured** — bash reds at `:87` today *because* it produces "command not found." Parameterizing turns that red into a green assertion of the correct bash behavior.

**Rename** `testMultiLinePasteIsNotAutoExecuted` → capability-neutral (e.g. `testMultiLinePasteMatchesShellBracketing`): "IsNotAutoExecuted" describes only the zsh arm. **Builds on `harden-paste-wrap-assertion`:** that change makes the positive line-present checks (`:82`/`:84`) wrap-tolerant (the wide-prompt zsh soft-wrap); this change keeps that wrap-tolerance and adds the bash arm + the `bracketedPasteMode` branch. If `harden-paste-wrap-assertion` has not landed when this applies, fold its wrap-tolerance in here.

**If layer-3 ever ships:** the bash arm flips from "executed" to "guarded" — a red→green this test *notices*; a skip would have silently kept skipping. So even anticipating the guard, the assertion is the more informative choice (Open-Question Q2).

### D3 — Expose `bracketedPasteMode` as a new DEBUG state-dump field (harness delta)

Add the focused pane's `terminal.bracketedPasteMode` to the state-dump JSON (`App/UITestDump.swift` + the `writeStateDump` callers), `#if DEBUG` + `-UITestGridDump`-gated, observe-only. Per the AGENTS.md harness-coupling rule this is a new observable → a `verification-harness` spec delta (the field + an e2e scenario) and a harness task. **Why a dump field rather than an XCUITest-side probe:** the custom-drawn view exposes nothing to accessibility; the state dump is the only deterministic out-of-process channel.

### D4 — Semantic-capture family: assert-active, else crisp-negative, else honest-skip (per-test, from the measured divergence)

For each of the 19 methods: when capture is live (zsh arm), assert the real behavior (blocks form; sidebar populates). When it is not (bash arm), prefer a **crisp negative** where one is meaningful and cheap — e.g. no OSC 133 command boundaries recorded / the semantic sidebar stays empty (this catches "zsh-only injection leaked into bash" or "the gating broke"). Only where the capability-absent case admits **no** meaningful assertion does the silent `guard … else { return }` become `throw XCTSkip(…)`. The per-test choice is reconciled at apply against `add-zsh-test-image`'s measured divergence (which methods produced a `"…capture inactive…"` attachment vs a real assertion). This is where the residual last-resort skips live — acceptable on the non-blocking job (D1).

### D5 — The predicate is the *observed* capability, sampled after readiness — never shell identity

The branch predicate must track what the terminal *actually* negotiated (a user could run bash 5.1, or a future shell): `bracketedPasteMode` from the state dump / `waitForSemanticCaptureActive()`, evaluated **after** the computed-marker shell-readiness gate (`harden-churn-shell-readiness`) so it is never sampled before the shell enables bracketed paste at its first prompt. *Rejected:* keying on `$SHELL`/`--version` (brittle; re-introduces the fragility we are removing) or on a rig env var like `XTTY_EXPECT_ZSH` (the rig asserting a belief, not the test observing reality — a misconfigured rig would then mis-assert a capable shell).

### D6 — The zsh rig is where the capability-present arm gets real coverage

`add-zsh-test-image` deferred "make the validator routinely aware of the zsh rig" to here. This change updates `test-validation` (the environment enumeration + a scenario) and the `xtty-test-validator` agent definition so a full sweep runs the whole suite on the zsh golden (capability-present arm asserts; the bash rig runs the same suite on the capability-absent arm). **Definition-delivery caveat:** agent-definition edits reach spawns with unpredictable lag — bump the `Definition:` stamp and verify by report stamp, never assume delivery (measured on this same agent).

### D7 — Sequencing with the sibling paste change

Recommended order: `harden-paste-wrap-assertion` first (small, green-now — wrap-tolerant zsh `:82`/`:84`), then this change (parameterize + rename + bash arm), **superseding** harden's edits by folding them into the parameterized test. `add-zsh-test-image` (archived) supplied the measured divergence. This change archives **after** `harden-paste-wrap-assertion`. The change-set-aware critic pass (pre-archive) checks this ordering + the red→green framing.

## Risks / Trade-offs

- **Parameterized tests carry two expected outcomes to maintain** (more than a single assertion + skip). → *Mitigation:* the two arms are small and the predicate is explicit; the symmetry (the `:87` inversion) keeps them legible.
- **The bash paste arm asserts a "footgun" behavior** (auto-execute). → *Mitigation:* the layer-2 forwarding-fidelity framing (D2) — both arms are *correct xtty behavior*; it is current-and-measured, and if a layer-3 guard lands the arm updates red→green (more informative than a skip).
- **Last-resort skips remain for parts of the semantic family** (D4), so the non-blocking bash job still shows some skips. → *Mitigation:* that is honest accounting (not a vacuous pass); the zsh rig asserts them for real; the required gate (`test-core`) is unaffected.
- **Dropping the partition means CI's non-blocking `build-and-test` runs the shell-dependent tests on bash** (asserting the bash arm, or skipping). → *Mitigation:* that is the point — real bash-arm coverage in CI; `packer/README.md` + §19b document the expected per-rig outcomes so the investigator classifies them.

## Migration Plan

Additive and reversible; no product surface touched. The parameterized assertions + the `bracketedPasteMode` field can land incrementally; `make test` still runs the whole suite. Rollback is reverting the `AppUITests/` edits + the dump field — no `project.yml`/scheme change to undo (the partition is never introduced).

## Open Questions

- **Q1 (layer-3 paste guard)** — does xtty intend a terminal-level "confirm multi-line paste" guard (iTerm2-style)? If **yes**, the bash paste arm is a future red→green target; frame its assertion as "current forwarding behavior," not "desired end state." If **no**, bash-executes is stable. Either way parameterizing beats skipping (D2). Does not block this change.
- **Q2 (per-test assert-vs-skip for the semantic family)** — which of the 19 admit a crisp capability-absent negative vs a last-resort skip? Decided at apply from `add-zsh-test-image`'s measured divergence (D4).
- ~~Q (XcodeGen `testPlans:` fidelity)~~ — **dissolved** by dropping the partition (D1).
