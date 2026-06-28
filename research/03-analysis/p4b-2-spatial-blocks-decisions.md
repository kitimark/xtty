# P4b-2 spatial blocks — explore-phase decisions (jump-to-prompt + copy-output + the fork)

> **Provenance:** Drafted 2026-06-28 during an `/opsx:explore p4b-2` session, after **P4b-1 (`add-file-link-open`) shipped and archived** (so P4b-1 is the fork-free half of P4b; this doc covers the fork-gated half). Produced by a research workflow (`p4b2-decisions-research`): 6 parallel source-readers (fork-anatomy + Tier-0 feasibility, visual-select, terminal-UX conventions, xtty integration cost, SwiftTerm upstream health + fork mechanics, anchor correctness) → **4 adversarial verifiers** on the load-bearing technical claims → a per-decision synthesis. 11 agents, ~578k tokens. All fork access-levels were read against the **SwiftTerm `v1.13.0`** checkout (commit `8e7a1e1`); the load-bearing claims were independently refuted/confirmed (cited inline). No code written.

> _Topic scope:_ Lock the three decisions that shape **P4b-2 `add-spatial-blocks`** — the only fork-gated milestone (in-terminal spatial ops on the P4a OSC-133 command blocks): (1) **fork now** vs ship fork-free first; (2) **tier scope** (jump + copy vs also visual-select); (3) **invocation surface** (keyboard vs sidebar). Builds on [P4 semantic-capture decisions](p4-semantic-capture-decisions.md) (the `Block` data model + the pre-committed Option-D fork) and [P5 sidebar + P4b sequencing](p5-sidebar-and-p4b-sequencing.md) (which first sketched the fork and an invalidation scheme that this doc **corrects**).

---

## Headline decision (all three locked, high confidence)

| # | Decision | Choice |
|---|----------|--------|
| **D1** | Fork SwiftTerm now, or wait for the P8 own-renderer? | **Fork now** — a **2-accessor** fork (not 3), scoped to Tier 1 |
| **D2** | Tier 1 (jump + copy) only, or also Tier 2 (visual on-screen select)? | **Tier 1 only** — defer Tier 2 (it pierces the engine-only seam, not because it's fragile) |
| **D3** | Keyboard-native or sidebar-driven invocation? | **Keyboard-native** (Cmd+Shift+↑/↓ + copy-output keybind); clickable per-block sidebar = a separate **P4b-3** |

```
 P4b-1 ✅ (fork-free)        P4b-2 — THIS (2-accessor fork)        P4b-3 (later, fork-free)     CONDITIONAL
┌──────────────────────┐   ┌──────────────────────────────┐   ┌──────────────────────────┐   ┌──────────┐
│ file:line click→edit  │──▶│ jump-to-prompt (Cmd+Shift+↑↓) │──▶│ clickable per-block        │──▶│ P8 own   │
│ D7 scheme guard       │   │ robust copy-output → clipboard │   │ sidebar (Tab▸Pane▸Block)   │   │ renderer │
│                       │   │  + flash/toast confirmation    │   │ click row → focus + jump   │   │ (fork    │
│ on P4a cwd            │   │ engine-only; keyboard-native   │   │ on P5's sidebar            │   │  moot)   │
└──────────────────────┘   └──────────────────────────────┘   └──────────────────────────┘   └──────────┘
                              ✗ Tier 2 visual-select deferred (forks the VIEW, P7 Metal re-verify)
```

---

## What the adversarial pass overturned

The verification phase earned its keep — it overturned or sharpened **four** claims the prior explore had carried in. These are the load-bearing corrections; do not re-introduce the refuted versions.

| Claim carried in | Verdict | What actually holds |
|---|---|---|
| Fork-free **Tier-0 copy** is a fine warm-up | ❌ **REFUTED** | Silently wrong in exactly the states a user wants old output — scrolled up (`yDisp != yBase`) or output that overflowed scrollback (the recorded `C` index rebases as the `CircularList` head recycles). `getText` **clamps instead of throwing**, so you paste blank/truncated/mismatched text with no signal. A trust-killer; do not ship even temporarily. |
| The fork is **"3 accessors"** | ❓ **PARTIAL** | It's **2** for Tier 1 (`getScrollInvariantCursorLocation` + `scrollbackBase`). The scroll *action* `scrollTo(row:)` is **already public** (`AppleTerminalView.swift:1846`); accessor #3 (`setSelection`) was only for the deferred Tier 2. |
| Tier-2 visual-select is **fragile / low-value** | ❌ **REFUTED** | It's actually *robust*: selection is stored in **absolute buffer coords**, survives scroll (`scrollTo` only mutates `yDisp`) and focus change, and is **preserved during streaming output when mouse-reporting is off** (`AppleTerminalView.swift:1899-1905`). Defer it for a *different* reason — see D2. |
| `(generation, absoluteRow)` invalidated on **`linesTop` decrease** | ❌ **REFUTED** | The dangerous one. **Window resize-trim and width-reflow shift line indices without ever touching `linesTop`** (`Buffer.swift:468-479` resize `trimStart`; `:889-1018,1079-1092` reflow; `:540-547` `changeHistorySize`) → a stale anchor resolves to the **wrong line and is *not* invalidated** (false validity). The naive detector also over-fires on CSI-3J and alt-screen. The corrected model is below. |

---

## Verified fork anatomy — 2 accessors, engine-only (D1, D2)

All re-confirmed against `v1.13.0` (`8e7a1e1`). The two coordinate ingredients jump needs are genuinely module-internal, so the fork is unavoidable for jump and for trim-robust copy:

- ✅ `buffer.yBase` and `buffer.linesTop` are **internal-by-omission** (`Buffer.swift:32`, `:27`; backing `private var _yBase` at `:22`). `linesTop` is the monotonic, trim-invariant base counter (comment `Buffer.swift:25-26`).
- ✅ `buffer` is **`public private(set)`** (`Terminal.swift:326`), so a `public extension Terminal` accessor can reach `yBase`/`linesTop` with no further plumbing.
- ✅ The accessors mirror an **already-public first-class idiom**: `getScrollInvariantLine(row:)` = `lines[row - linesTop]` (`Terminal.swift:743-748`) and `getScrollInvariantUpdateRange()` (`:5053`). This is why the fork is trivial *and* plausibly upstreamable.
- ✅ `getCursorLocation().y` is **`yBase`-relative, not `yDisp`-relative** (`Terminal.swift:5079`; the absolute-index idiom `buffer.lines[buffer.yBase + buffer.y]` at `:4569`, `AppleTerminalView.swift:1666`). ⚠️ Its doc comment "relative to visible part of display" (`Terminal.swift:5076`) is **misleading** — document this on the new accessor so nobody reintroduces a scroll-dependent off-by-`(yBase − yDisp)` bug.
- ✅ `scrollTo(row:)` (`AppleTerminalView.swift:1846`) and `scroll(toPosition:)` (`:1824`) are **already public** — so the jump *scroll* needs no fork; `setViewYDisp` (the internal path) stays internal. `scrollTo` takes a `buffer.lines` index, so the stored scroll-invariant row is converted via `displayRow = absoluteRow − scrollbackBase`.
- ✅ `getText(start:end:)` (`Terminal.swift:5869`) + `Position` (`Position.swift:11`) are public and correctly reconstruct **wrapped** output (newline only on hard breaks — `Terminal.swift:6570-6592`, `Line.swift:16-19`). So copy is engine-only; the fragility was never in the text join, only in deriving the `Position` range — which the fork fixes.

**The fork, precisely:** one new in-module file `Sources/SwiftTerm/XttyAccessors.swift`, `public extension Terminal`:

```swift
// #1 — trim-invariant absolute cursor row (sibling to the public getScrollInvariantLine)
public func getScrollInvariantCursorLocation() -> Position {
    Position(col: buffer.x, row: buffer.yBase + buffer.y + buffer.linesTop)   // normal-buffer-pinned
}
// #2 — reverse-map (absoluteRow − scrollbackBase = scrollTo row) + reset signal
public var scrollbackBase: Int { buffer.linesTop }
```

Do **not** edit `Buffer.swift`/`Terminal.swift` (zero rebase-conflict surface; the new-file strategy only breaks loudly at compile time if upstream renames `yBase`/`linesTop`, stable for years).

### Why Tier-2 accessor #3 is categorically different (D2)

✅ `setSelection(start:end:)` is a **public member** (`SelectionService.swift:105`) and `Position` is public — but the **`SelectionService` type is internal** (`:16`) and the view's `selection` ivar is internal (`Mac/MacTerminalView.swift:151`). Selection lives **on the VIEW, not the headless `Terminal`**. So accessor #3 would punch a public hole in the **render layer**, violating xtty's hard rule that all logic talks to the engine so the renderer stays swappable — and it would need re-verification at the **P7 Metal-renderer gate**. The copy *goal* is fully met engine-only (`getText → NSPasteboard`); Tier-2's one real benefit (seeing what you grabbed before paste) is delivered **fork-free via a transient flash/toast**. A durable highlight would *also* need a guarded `feedPrepare` opt-out (default `allowMouseReporting = true` wipes a programmatic selection on the next feed — globally disabling it breaks vim/tmux/htop mouse) → a larger, less-upstreamable bundle. Hence Tier 2 is a deliberate **fork-the-view** decision for later, not a fragility call.

---

## The corrected invalidation model (D1 — supersedes the p5-sequencing sketch)

The jump anchor is `absoluteRow = buffer.y + buffer.yBase + buffer.linesTop`, captured **synchronously inside the OSC-133 handler** (at `A` for jump-to-prompt and/or `C` for jump-to-output), on the main-actor engine-feed path (`PaneController.swift:117-126`). With the **fork** accessor this is correct **regardless of scroll position** (the engine always writes the cursor to `lines[yBase + y]`) — so the prior "does `C` fire at bottom?" worry only ever mattered for the *fork-free proxy*, which we're not shipping.

The absolute row **is trim-invariant** under ordinary scrollback push (trim shifts content down one slot and bumps `linesTop` by one, leaving `arrayIndex + linesTop` fixed — the only `linesTop += 1` site is `scroll()`, `Terminal.swift:5258-5261`). But the **p5-sequencing reset detector ("bump generation when `linesTop`/`scrollbackBase` decreases") is unsound** (refuted above). The robust model:

1. **Resize-trim / width-reflow / `changeHistorySize`** shift indices *without* touching `linesTop` → **invalidate ALL anchors on the public `sizeChanged` delegate.** Spike: these are reachable *only* via `resize()`/`changeHistorySize()`, both of which fire `sizeChanged` (`Terminal.swift:4048,4276,6670`). Fork-free, app-side, conservative. (Window *grow* is a benign false-positive — anchors die though still valid; jump stops working for old blocks until new commands run. Accepted.)
2. **`clear` / CSI-3J / reset** set `linesTop = 0` (`Buffer.swift:355`, `Terminal.swift:2369`) — detect via the **high-water-drop of `liveTop = yBase + linesTop`** (monotonic across normal output; drops on every reset), **sampled per feed chunk** (not just at OSC boundaries) to avoid a `clear; <flood>` masking the reset within one PTY chunk.
3. **Pin the accessor to the normal buffer** (the alt buffer is a separate object with `linesTop = 0`, `Terminal.swift:771-799`) and **gate capture/jump during alt-screen** (reuse P4a's `isCurrentBufferAlternate` tracking) — else entering vim falsely invalidates everything.
4. **Jump math:** `displayRow = absoluteRow − scrollbackBase`; clamp via `getScrollInvariantLine(absoluteRow) == nil ⇒ scroll to top`; generation/epoch mismatch ⇒ anchor dead ⇒ graceful no-op + toast.

**Anchor placement is consistent with P4a, not a reversal:** P4a forbade the *bottom-anchored `y + yDisp` proxy that rots on trim* and explicitly pre-committed to *this* fork-based absolute anchor (Option D). The anchor stays an **optional/best-effort** field on `Block` (the MATH in `XttyCore`, the `scrollTo` CALL in the app target), so P4a's coordinate-free invariants + 134 unit tests stay green and jump/copy degrade gracefully.

### ⚠️ Open design tension (decide in the proposal)
The **anchor-correctness reader prefers folding a tiny engine `resetGeneration` counter into the fork** (incremented at the two `linesTop = 0` sites + the shrink-trim sites) for airtight, sample-free reset detection — "if you're forking anyway, fork once and include the epoch counter." The **synthesizer prefers staying at exactly 2 accessors** + `invalidate-all-on-sizeChanged` + per-feed `liveTop` sampling, to keep the fork in one new file and avoid editing churny `Buffer.swift`/`Terminal.swift` (higher rebase cost, weaker upstream odds). Resolve via the masking spike below: if `clear; <flood>` masking is observable in one feed chunk, prefer the in-engine counter; otherwise keep the 2-accessor + sampling model.

---

## Per-decision rationale

### D1 — Fork now (2-accessor, Tier 1) ✅ high
Fork-free is a dead end: it **cannot jump at all** (the dominant idiom is a viewport scroll to a prompt row, which needs the trim-invariant index), and its copy is **silently wrong** in the states a user is most likely in when reaching for old output, plus it forces eager per-block `String` retention (fights lean-memory). The fork is mechanically tiny (one new file; one revision-pin line `XttyCore/Package.swift:23`; regen `Package.resolved` + the gitignored `.xcodeproj`; `project.yml` untouched), MIT, no CLA, idiom-matching, plausibly upstreamable — and **is itself the hedge** against SwiftTerm's bus-factor-1 (one maintainer, bursty cadence: 10 releases Dec 2025–Mar 2026 then a ~3-month quiet stretch since `v1.13.0`). Strategy: fork the **v1.13.0 tag** (not `main`, to avoid chasing ~79 unreleased commits) → `kitimark/SwiftTerm` revision-pinned; open a small upstream PR in parallel; repoint to upstream if/when it lands.

### D2 — Tier 1 only; defer Tier 2 ✅ high
Not on fragility grounds (refuted) — on the **architecture seam + sequencing**: accessor #3 forks the *view*, not the engine (P7 Metal-gate exposure). Copy's full value is engine-only; Tier-2's verification benefit is covered fork-free by the flash/toast. Revisit Tier 2 only if user feedback shows demand, evaluated as a deliberate fork-the-view bundle (accessor #3 + guarded `feedPrepare` opt-out + trim-invariant selection anchoring + Metal re-verify).

### D3 — Keyboard-native; sidebar = P4b-3 ✅ high
Strong cross-terminal convergence: jump-to-prompt is universally a **keyboard-native viewport scroll**, and **Cmd+Shift+↑/↓ is the exact iTerm2 *and* Ghostty macOS default** (kitty `ctrl+shift+z/x`, WezTerm `Shift+↑/↓` — same arrow/scroll idiom, different modifier). **No keyboard-first terminal uses a clickable block-list as the primary surface** — only Warp, whose whole window *is* blocks. Copy-output is predominantly a keyboard one-shot for the last command (iTerm2 `Cmd+Shift+A`; kitty `ctrl+shift+g`). Cost agrees: the keybind pipeline is **S–M** (xtty's action→chord→menu→selector→command→controller path is already repeated ~13×, and new actions inherit `keybind-<action>` overrides for free — `KeyChord.swift:5-19`, `Keybindings.swift:84-93`, `KeybindAdapter.swift:36-41`, `MainMenu.swift:68-93`, `XttyTerminalView.swift:70-78`); the sidebar block-list is **M** net-new SwiftUI (`SessionSidebar.swift` is flat Tab▸Pane; `focusPane` is focus-only, `TerminalWindowController.swift:225-229`) and a grid right-click "copy output" would be **L** (no context-menu surface exists today). Both surfaces consume the *same* fork+anchor plumbing, so cost decides → keyboard wins; the sidebar (which is what designates an *arbitrary* old block for copy/jump) is the natural **P4b-3** follow-up on P5's sidebar.

---

## Recommended P4b-2 scope spine (for the proposal)

1. **Fork** SwiftTerm at the `v1.13.0` tag → `kitimark/SwiftTerm`; one new file `XttyAccessors.swift` (`public extension Terminal`) with `getScrollInvariantCursorLocation()` (normal-buffer-pinned) + `scrollbackBase`; repoint `XttyCore/Package.swift:23` to a revision pin; regen `Package.resolved` + `.xcodeproj`; open the upstream PR. *(Decide the `resetGeneration`-in-fork tension first — see spike below.)*
2. **`XttyCore`:** optional best-effort `(epoch, absoluteRow)` anchor on `Block` + `runningBlock`, captured synchronously in the OSC-133 handler at `A`/`C`; keep coordinate-free invariants + the 134 tests green.
3. **`XttyCore` (view-free) invalidation model:** epoch bump on `liveTop` high-water-drop (per feed chunk); an `invalidateAll()` the app calls on `sizeChanged`; skip capture/jump during alt-screen; jump-row math + `getScrollInvariantLine == nil ⇒ top` clamp.
4. **App keybinds:** `jump-prev-prompt` / `jump-next-prompt` / `copy-command-output` `KeybindAction`s with `keybind-<action>` overrides; defaults Cmd+Shift+↑ / Cmd+Shift+↓ (conflict-audited) + a copy chord; menu items + `@objc` selectors + validate whitelist + `PaneController` forward; per-feed `liveTop` sampling + `sizeChanged → registry.invalidateAll()` hooks.
5. **App actions:** jump = public `scrollTo(row:)`; copy = on-demand `getText(start:end:)` over the stored range → `NSPasteboard` + transient flash/toast; epoch-mismatch/trimmed ⇒ graceful no-op + toast.
6. **Harness:** DEBUG dump gains `lastJumpTargetRow` + `lastCopiedOutput`; injected-zsh e2e asserts jump scroll + copy correctness **including a scrolled-up case and a post-resize graceful-degradation case**.

**Deferred, each its own change:** Tier 2 visual on-screen selection (fork-the-view); **P4b-3** clickable per-command-block sidebar on P5's Tab▸Pane sidebar.

---

## Spikes resolved during implementation (2026-06-28)

The `add-spatial-blocks` change was implemented; the spikes below were all resolved in code:
- ✅ **[fork size — KEY] Stays a 2-accessor fork.** `reflow` is reachable only from `Buffer.resize` (`:503`), and the only caller of `terminal.resize` is `AppleTerminalView.resize` (`:1934`), which fires `sizeChanged` right after; in-band DECCOLM fires it too — all paths reach `PaneController.sizeChanged` (a previously-empty stub now calling `bumpEpoch`). `changeScrollback` skips `sizeChanged` but xtty calls it only at config time (pre-anchor). So **no in-engine `resetGeneration` counter is needed.**
- ✅ **[masking] Closed by `scrolled`-delegate sampling.** `liveTop` is sampled on every scroll (via the link proxy's `onScrolled` hook) as well as at OSC marks; a `clear; <flood>` scrolls, firing the drop detection — so the masking window is closed in practice. Confirms the 2-accessor decision.
- ✅ **[conflict audit] Cmd+Shift+↑/↓ is free** in both presets (focus uses Cmd+Opt+arrows); bound as menu key-equivalents so the menu intercepts ahead of the view. Copy = **Cmd+Shift+C**.
- ✅ **[copy semantics] Excludes the trailing prompt** — the copy range is `[outputStart(C) … outputEnd(D)]`; the e2e asserts the copied text contains the output but not the command echo. Default scope: the running block else the last completed block.
- ✅ **Mechanism: pinned submodule + drop-in (no fork repo)** — `external/SwiftTerm @ v1.13.0` + `patches/swiftterm/XttyAccessors.swift` via `scripts/bootstrap-swiftterm.sh` + a local-path SPM dep; the App seam was lit up to read the real accessors. 162 `XttyCore` unit + 23 XCUITests green (3 spatial e2e on real injected zsh). See [SwiftTerm fork vs patch-in-repo](swiftterm-fork-vs-patch-strategy.md).

## Open spikes / sub-decisions (original; resolved above)

- **[fork size — KEY]** Confirm `invalidate-all-on-sizeChanged` fully covers the reflow + resize-trim + `changeHistorySize` holes (spike strongly indicates yes — all reachable only via `resize()`/`changeHistorySize()`, both firing `sizeChanged`), so no in-engine epoch counter is needed. Verify there is no other reflow/trim entry point and that xtty receives `sizeChanged` before the next anchor-consuming action. **This decides whether the fork stays 2-accessor or grows the `resetGeneration` counter.**
- **[masking]** Confirm per-feed `liveTop` sampling reliably catches `clear`/CSI-3J/reset **and** the `clear; <flood>`-within-one-feed-chunk case; if masking is observable, fold the tiny engine `resetGeneration` counter into the fork instead.
- **[conflict audit]** Verify Cmd+Shift+↑/↓ isn't consumed by the SwiftTerm view or by macOS extend-selection-to-doc-start/end before the app-level handler, and is free across the common/iterm/ghostty maps (`Keybindings.swift:25-56`) + Edit/View/Find menus. **Do not** use plain Cmd+↑/↓ (Warp block-select + macOS doc-start/end). Pick the copy chord (iTerm2's `Cmd+Shift+A` vs a free chord like `Cmd+Shift+C`) with the same audit.
- **[copy semantics]** Does "output" exclude the trailing prompt (match iTerm2's BEFORE_OUTPUT→BEFORE_PROMPT to dodge the common off-by-a-region bug)? Default copy scope = last/current command vs the jump-selected prompt.
- **[doc the trap]** Note on the new accessor that `getCursorLocation()`'s "relative to visible display" comment is misleading (it's `yBase`-relative).
- **[graceful degradation]** Jump/copy gate on OSC-133; must fail gracefully (no-op/best-effort) under uncooperative host zsh / tmux / ssh — exactly as the upstream terminals do.

---

## Corrections folded back into the docs
- ❌ **`p5-sidebar-and-p4b-sequencing.md`** — the accessor-#2 "reset detection via `linesTop` decrease" claim and the Q-B framing that anchor validity hinges on at-bottom are **superseded** by this doc: with the fork the capture is scroll-position-independent, and the robust reset signal is `liveTop` high-water-drop + `invalidate-all-on-sizeChanged`, not a bare `linesTop`-decrease. (The "minimal fork" table there listed 3 accessors; for **Tier 1** it is **2** — the 3rd is Tier-2/visual-select, deferred.)
- ✅ The P4a pre-commit to "Option D: a fork-based absolute anchor" stands and is the basis for the anchor here.

## Sources
- **Workflow** (this session, 2026-06-28): `p4b2-decisions-research` — 6 source-readers → 4 adversarial verifiers (Tier-0 copy, fork count/reachability, Tier-2 fragility/value, anchor invalidation) → synthesis. All four verdicts are reflected above (REFUTED ×3, PARTIAL ×1); the refutations changed the answer.
- **SwiftTerm checkout** `v1.13.0` (`8e7a1e1`) — `…/SourcePackages/checkouts/SwiftTerm/Sources/SwiftTerm`: `Terminal.swift`, `Buffer.swift`, `CircularList.swift`, `SelectionService.swift`, `Position.swift`, `Line.swift`, `Apple/AppleTerminalView.swift`, `Mac/MacTerminalView.swift` (line cites inline).
- **xtty** — `XttyCore/Sources/XttyCore/{Block,BlockTracker→Block.swift,KeyChord,Keybindings,KeybindParser,SessionRegistry,TerminalSession}.swift`, `App/{PaneController,TerminalWindowController,SessionSidebar,KeybindAdapter,MainMenu,XttyTerminalView}.swift`, `XttyCore/Package.swift`.
- **Comparable terminals** (UX conventions, web-verified) — iTerm2 (marks, Cmd+Shift+↑/↓, "Select Output of Last Command" Cmd+Shift+A), Ghostty (`jump_to_prompt`, super+shift+arrow), kitty (`scroll_to_prompt`, `show_last_command_output`), WezTerm (`ScrollToPrompt`, semantic zones), Warp (block list).
- **Prior decisions** — [P4 semantic-capture decisions](p4-semantic-capture-decisions.md), [P5 sidebar + P4b sequencing](p5-sidebar-and-p4b-sequencing.md), [milestones P4](../04-design/02-milestones.md).
