## Context

Vendored SwiftTerm v1.13.0 (`external/SwiftTerm`, reconstituted by `scripts/bootstrap-swiftterm.sh` from a pinned checkout + `patches/swiftterm/xtty-accessors.diff`) implements two scroll-region-shift operations: `cmdScrollUp` (`Terminal.swift:4672`, handles `CSI Ps S` / SU) and `cmdScrollDown` (`Terminal.swift:4646`, handles `CSI Ps T` / SD). Both are reachable whenever a full-screen ncurses program (htop, and any program using ncurses' hardware scroll-region optimization) redraws a scrolled list — confirmed this session via a byte-exact real capture of htop replayed through a headless `Terminal`.

`cmdScrollUp` correctly branches on `marginMode` (the DECLRMM column-margin-mode flag): when it's off — the overwhelming common case, since almost no program enables DECLRMM — it does a full-width whole-line-object `splice` (delete-then-insert), moving entire `BufferLine` references. `cmdScrollDown` has no such branch: it *always* computes its shift width as `columnCount = buffer.marginRight - buffer.marginLeft + 1` and does a narrow, per-cell `copyFrom` bounded by `marginLeft`/`marginRight` — values that default to `0`/`0` and are never raised for the alternate-screen buffer full-screen programs run on (`Buffer.init`, `activateAltBuffer` — neither sets them; traced this session). So every `SD` shifts exactly one column, leaving the rest of the scroll region's columns untouched indefinitely. Full mechanism, numeric proof, and the byte-exact reproduction are in `research/03-analysis/scroll-reversal-redraw-corruption-forensics.md` §7.

## Goals / Non-Goals

**Goals:**
- Make `cmdScrollDown`'s shift width symmetric with `cmdScrollUp`'s: full-width when `marginMode` is off, narrow/margin-bounded only when it's genuinely on.
- Add a fast, precise, headless regression test that isolates the defect without a real PTY, app, or full-screen program.
- Add end-to-end coverage proving a real full-screen program's display survives a genuine wheel scroll-then-reversal gesture.

**Non-Goals:**
- Changing anything about mouse-wheel *routing* (which branch a gesture takes) — that logic is correct and untouched; this fixes what happens to the display *after* a program legitimately receives a wheel-routed scroll and redraws.
- Auditing or fixing `marginMode`-active (DECLRMM-enabled) behavior — that path is unchanged by this fix (it already branches correctly in both functions) and is exercised by essentially no real terminal program.
- Filing the upstream SwiftTerm PR — deferred to a maintainer action, per the precedent set by `fix-scroll-wheel-mouse-reporting` and `smooth-scroll-wheel-momentum`.

## Decisions

**D1 — Mirror `cmdScrollUp`'s exact `if marginMode {…} else {…}` shape onto `cmdScrollDown`, direction-mirrored.** `cmdScrollUp`'s non-margin branch does, per iteration of `p`: `splice(start: yBase+scrollTop, deleteCount: 1, items: [])` (delete the line scrolling off the top) then `splice(start: yBase+scrollBottom, deleteCount: 0, items: [blankLine])` (insert a fresh blank at the bottom) — moving content up. `cmdScrollDown`'s new non-margin branch is the direction-mirrored equivalent: delete the line scrolling off the *bottom* (`splice(start: yBase+scrollBottom, deleteCount: 1, items: [])`), then insert a fresh blank at the *top* (`splice(start: yBase+scrollTop, deleteCount: 0, items: [blankLine])`) — moving content down. The existing `marginMode`-true branch (the narrow per-cell copy, already correct for that case) is left completely unchanged in both functions.
   - *Alternative considered:* rewrite both functions to share one direction-parameterized helper. Rejected — `cmdScrollUp` is proven correct and heavily exercised; touching it risks a regression in already-working code for no benefit. The minimal, lowest-risk change adds only what's missing to `cmdScrollDown`.

**D2 — Land the fix as a new hunk in the existing `patches/swiftterm/xtty-accessors.diff`, not a second patch file.** Keeps the established one-patch/one-apply-script convention (`scripts/bootstrap-swiftterm.sh` already applies exactly one diff from a pristine reconstitution). This does change the patch's character from purely additive (new accessor methods, confined to `MacTerminalView.swift`) to also carrying a correctness fix inside `Terminal.swift` — worth calling out explicitly (in the patch's own header comment and in this change's narrative) since it's a departure from every prior hunk in this file, but doesn't warrant a separate mechanism.
   - *Alternative considered:* a second, separately-pinned patch file scoped to this fix. Rejected — no existing precedent for multiple patch files, and `bootstrap-swiftterm.sh` would need new plumbing for no real benefit; one file tracking "everything xtty needs upstream SwiftTerm to do differently" is simpler to reason about.

**D3 — Regression coverage in two tiers, both new:**
1. **Fast/precise (`XttyCoreTests`, headless, no PTY/app/real program):** reuse the existing `NoopTerminalDelegate` + `Terminal(delegate:)` pattern (`TerminalSessionTests.swift`) to construct a headless engine, enter the alternate screen (`DECSET 1049` — the confirmed-buggy configuration; the primary buffer's margin defaults weren't traced and may differ, so the test targets exactly the configuration known to be broken), set a scroll region via `DECSTBM`, write distinct full-width content into two or more rows inside the region (e.g. a row of all `'A'` and a row of all `'B'`), issue `SU` then `SD`, and assert every column of the shifted row reflects the correct content — not just column 0. This is the test that would have caught the original defect deterministically, in milliseconds, without any of this session's live-app/real-htop investigation.
2. **End-to-end (`AppUITests`):** drive a real full-screen mouse-tracking program through a genuine wheel scroll-then-reversal (mirroring the already-established pattern in `XttyMouseWheelUITests`/`testWheelScrollsRealMouseTrackingPager`), then assert via the existing DEBUG grid-dump content-assertion channel that the expected rows show correct, non-duplicated content after the reversal.
   - *Alternative considered:* end-to-end coverage only. Rejected — the forensics investigation this session showed how much faster and more precise a headless synthetic repro is than driving a real app/program; both tiers are cheap enough to add and serve different purposes (tier 1 pins the exact defect at the engine level; tier 2 proves the real daily-driver workflow is fixed).

**D4 — Spec placement avoids the two requirements `smooth-scroll-wheel-momentum` (concurrently open, 20/22 tasks done) has pending edits against** (`terminal-session`'s "Mouse-wheel routing to the terminal" and `verification-harness`'s "Mouse-wheel routing is observable" / "…end-to-end coverage"). Extending `terminal-session`'s "Interactive terminal input and output" requirement (untouched by that change, already carries the general redraw-correctness principle and an analogous resize scenario) and adding a **new** `verification-harness` requirement avoids a same-requirement collision between two concurrently open changes, regardless of which archives first.

## Risks / Trade-offs

- **[Risk] Mirroring `cmdScrollUp`'s shape assumes that function is itself fully correct — it was validated only by this session's research, not by an independent formal proof.** → Mitigation: the new headless regression test (D3.1) directly asserts full-width-shift correctness by content, not by code-shape resemblance; if `cmdScrollUp` had a latent issue, the mirrored `cmdScrollDown` would inherit it and the test would still need to pass on its own merits.
- **[Risk] This is the first fix to vendored SwiftTerm's core VT engine logic in this project (prior patches were purely additive accessors) — a wider risk surface than earlier hunks.** → Mitigation: the change is narrowly scoped to one function's shift-width computation, using an already-proven-correct sibling as the template; full regression (`make test-core` + the Tier-1/VM acceptance matrix) is required before archival, per the existing test-validation delegation rule.
- **[Risk] `marginMode`-active (DECLRMM) behavior in `cmdScrollDown` is unchanged and untested by this fix** — if it has its own latent bug, this change won't surface it. → Accepted as a Non-Goal; DECLRMM is exercised by essentially no real terminal program, so it's out of scope here.

## Migration Plan

No data/user migration. Re-run `scripts/bootstrap-swiftterm.sh` after the patch update to reconstitute `external/SwiftTerm` from the pristine pin with the revised diff applied. Rollback is trivial: revert the new hunk (a single self-contained function edit) and re-bootstrap — the `marginMode`-true path is untouched throughout, so there's no partial/inconsistent state to unwind.

## Open Questions

- Whether to file the upstream SwiftTerm PR immediately alongside this change or continue deferring it as a follow-up maintainer action — deferred per established precedent; no PR link expected from this change.
