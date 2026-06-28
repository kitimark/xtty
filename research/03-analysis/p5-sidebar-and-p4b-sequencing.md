# P5 sidebar + P4b sequencing — explore-phase decisions

> **Provenance:** Drafted 2026-06-28 during an `/opsx:explore p4b` session, after **P4a (`add-semantic-capture`) was implemented and archived**. Produced by two research workflows over **local source** (the SwiftTerm SPM checkout, xtty's `App`/`XttyCore`, the `research/` + `openspec/` trees): (1) `p4b-directions-research` — 5 source-readers on the four strategic directions → adversarial verify → synthesis; (2) `p4b-open-questions-research` — 6 source-readers (one per open question) → 2 adversarial verifiers → synthesis. The first run's separate verifier phase mostly failed on an output-schema retry cap, but **the load-bearing access-level claims were independently re-verified by hand** (greps cited inline); the second run's verifiers both returned clean verdicts. No code written.

> _Topic scope:_ Lock the **sequencing** between P5 (the session-progress sidebar — the user's #1 feature, [requirements H1](xtty-requirements.md)) and **P4b** (the deferred in-terminal spatial ops), and resolve the open questions that shape the P5 change. Builds directly on [P4 semantic-capture decisions](p4-semantic-capture-decisions.md) (the data model this consumes) and [milestones P4/P5](../04-design/02-milestones.md).

---

## Headline decision: **ship P5 before P4b, and do not fork SwiftTerm yet**

P4a's `Block` model already carries everything the sidebar needs (command / exit / cwd / timestamps / state), entirely view-free in `XttyCore`. The sidebar is therefore **100% fork-free** and it **absorbs the highest-value slice of P4b** — "which command failed / what's running, at a glance." P4b's genuinely fork-gated value is only the *in-terminal spatial* affordances; defer those behind one tiny additive fork, and **drop gutter fail-marks** (the sidebar delivers that value, and a true in-terminal gutter pierces the swappable render seam the architecture rule protects).

```
 DONE (fork-free)          NEXT change (fork-free)         LATER change (one fork)      CONDITIONAL
┌──────────────────┐   ┌───────────────────────────┐   ┌───────────────────────┐   ┌──────────┐
│ P5 sidebar ✅     │──▶│ P4b-1 add-file-link-open  │──▶│ P4b-2 add-spatial-    │──▶│ P8 own   │
│ idle/running/ok/ │   │ • file:line click→editor  │   │   blocks              │   │ renderer │
│ fail/fullScreen, │   │ • D7 scheme guard         │   │ jump-to-prompt +      │   │ (fork    │
│ Tab▸Pane, click→ │   │ • on P4a cwd + default-on │   │ copy-output [+ visual │   │ moot)    │
│ focus pane       │   │   implicit links +        │   │ select] (2–3 accessors)│   │          │
│                  │   │   requestOpenLink delegate│   │                       │   │          │
└──────────────────┘   └───────────────────────────┘   └───────────────────────┘   └──────────┘
   at-a-glance (H1)       agent-CLI win; feeds P6           in-terminal-nav win        ✗ gutter marks dropped
```

---

## Update (2026-06-28, post-P5): **P4b splits in two — file:line click-to-open is fork-free**

> _Added after P5 (`add-session-sidebar`) shipped and archived, during a follow-up `/opsx:explore p4b`. Produced by a repo-wide reference sweep + direct reads of the SwiftTerm `v1.13.0` checkout. All fork access-levels below were **re-verified unchanged** today (still `from: "1.13.0"`; `linesTop`/`yBase` internal; `getScrollInvariantLine`/`getText`/`Position` public; `setSelection` a public member on the internal `SelectionService`)._

The original framing above (and the milestone/AGENTS trackers) bundled **file:line click-to-open** with jump-to-prompt + copy-output as "all behind the fork." Reading SwiftTerm's actual link machinery shows that is wrong: **file:line click-to-open needs no fork.** So P4b is two independent changes:

- **P4b-1 `add-file-link-open` — FORK-FREE.** Click a `path:line:col` (or bare/relative/rooted path) → open it in the user's editor, resolved against the pane's live cwd. Plus the deferred **D7 scheme guard** (a safety win on its own). Builds on P4a's OSC 7 cwd. This is the **agent-CLI win** (agents emit `file:line` constantly) and the on-ramp to the **P6 file/diff view**.
- **P4b-2 `add-spatial-blocks` — needs the 2–3 accessor fork** (anatomy unchanged, see next section): **jump-to-prompt** + **copy-output** [+ **visual-select**]. This is where the "do we fork SwiftTerm yet?" decision actually lives; P4b-1 lets it be deferred again.

**Why file:line click-to-open is fork-free (evidence, SwiftTerm `v1.13.0`):**
- ✅ **Implicit link detection is ON by default** — `public var linkReporting: LinkReporting = .implicit` (`Mac/MacTerminalView.swift:599`); clicks resolve via `.explicitAndImplicit` (`:2108`).
- ✅ **The implicit matcher already detects file paths, not just URLs** — `ghosttyImplicitLinkRegex` (`Terminal.swift:6106`, a port of Ghostty's matcher) has three branches: scheme-URLs, rooted/relative paths (`./ ../ ~/ $VAR/ /abs`), and **bare relative paths** (`src/foo.swift`). The `:line:col` suffix survives because `:` is in `pathChars`; only a *trailing* colon is trimmed (`noTrailingColon`).
- ✅ **The click is delivered through a delegate, not an override** — `requestOpenLink(source:link:params:)` is a `TerminalViewDelegate` protocol method (`Apple/TerminalViewDelegate.swift:59`), so `PaneController` (already a `LocalProcessTerminalViewDelegate` with `hostCurrentDirectoryUpdate`) can implement it directly. **No `open`-vs-`public` problem** (contrast `progressReport`), no `TerminalView` internals, no fork.
- ✅ **xtty currently implements no `requestOpenLink` handler** → it silently inherits SwiftTerm's default (`NSWorkspace.open` on *anything*). That is exactly the **deferred D7 gap** (P3a `terminal-links` design): file:line click-to-open is "finish the D7 delegate + resolve-vs-cwd + open-in-editor," not new fork work.

**P4b-1 shape (for the proposal):** implement `requestOpenLink` in `PaneController` → classify (URL vs `path[:line[:col]]`) → **scheme guard** (whitelist `http(s)`/`file`/`mailto`; route file-paths to the editor; deny/confirm app-launching schemes) → resolve relative paths against the pane's live cwd → open via a configurable opener.

**P4b-1 open questions (small, not blockers):**
- **Editor invocation** — a `file-opener` / `editor` config key? Per-editor line syntax (`code -g f:L:C`, `vim +L f`, `idea --line L f`), `$EDITOR` + heuristics, or macOS `open`?
- **One cheap spike** — click `foo.swift:42:10` in a running build and log the exact `link` string the delegate receives, to confirm `:42:10` is captured before designing the parser (regex says yes; confirm empirically — needs a manual click).
- **Relative resolution** — resolve bare paths against the pane's *current* cwd (best-effort; the standard OSC 7 caveat for scrolled-back lines).

## The minimal P4b fork, precisely (for when P4b-2 lands)

Three additive public declarations in 2 files, all symmetric with the **already-public** `getScrollInvariantLine(row:)` (`Terminal.swift:743`) — so they read as "finish the public scroll-invariant surface," which is why upstream acceptance is plausible:

```swift
// Terminal.swift, near getCursorLocation()
public func getScrollInvariantCursorLocation() -> (x: Int, y: Int) {
    (buffer.x, buffer.y + buffer.yBase + buffer.linesTop)   // absolute, trim-invariant
}
public var scrollbackBase: Int { buffer.linesTop }          // reverse-map + reset detection
// Apple/AppleTerminalView.swift, near getSelection()
public func setSelection(start: Position, end: Position) {
    selection.setSelection(start: start, end: end)          // forwards to internal SelectionService
}
```

**Why each is unreachable today (hand-verified):** `linesTop`/`yBase`/`lines` are internal-by-omission (`Buffer.swift:27,32,201`) on the `public private(set) buffer`; `view.selection` is internal (`MacTerminalView.swift:151`) and the `SelectionService` *type* is internal (`SelectionService.swift:16`, though its members are public). `Position` **is** public (`Position.swift:11`), so the signature is expressible cross-module.

| Spatial feature | anchor (#1) | scrollbackBase (#2) | setSelection (#3) | Verdict |
|---|---|---|---|---|
| jump-to-prompt | ✅ | ✅ | — | unlocked by #1+#2 |
| **copy** a command's output (robust) | ✅ | ✅ | — | unlocked by #1+#2 |
| **visual select** a command's output | ✅ | ✅ | ✅ (independent 2nd wall) | full fork |
| gutter fail-marks | ✅ | ✅ | — | **dropped** — geometry is fork-free (`cellSizeInPixels` public, `MacTerminalView.swift:2297`) but there is **no trim/reset invalidation signal** and the overlay entangles the render layer → fold value into the sidebar; revisit at P8 |

**Manifest to repoint:** only `XttyCore/Package.swift:23` (`from: "1.13.0"` → a fork `revision:`). `project.yml` never pins SwiftTerm (the App gets it transitively); `Package.resolved` and the gitignored `xcodeproj` regenerate. Strategy: GitHub fork pinned by commit, accessors in a **new** file (zero rebase-conflict surface), upstream PR filed in parallel; fall back to the pinned fork if upstream (bus-factor-1) stalls.

---

## Resolved open questions

| # | Question | Decision | Conf. | Key evidence |
|---|----------|----------|-------|--------------|
| **A** | Sidebar states; is "blocked" = failed or waiting? | Session-level enum **`idle / running / succeeded / failed / fullScreen`** (+ optional `waiting`), kept distinct from per-block `BlockState`. **"blocked" → `failed`** (have it today). `waiting` only from OSC 9;4 `.pause`, opportunistic. | High | `Block.swift:4-14,89-93`; `TerminalSession.swift` `isAlternateScreen`; `Terminal.ProgressReport` states |
| **B** | Does OSC 133 `C` fire at bottom → is fork-free jump viable? | **Yes, best-effort viable.** Foreground commands (preexec fires after Return → caret snap-to-bottom) emit `C` at `yDisp==yBase`. **Verifier: confirmed.** | High | `Terminal.swift:425` (`userScrolling` never set true on engine); `MacTerminalView.swift:2323-2332` (`ensureCaretIsVisible` snaps) |
| **C** | Grouping / data path / click target? | **Two-level `Tab ▸ Pane` tree**, scoped to the key window. Build the VM from `windowControllers` + `tree.leaves()` (the flat `SessionRegistry` is structure-blind). Click → focus the pane via the existing `setActivePane`. **No scroll-to-row.** | High | `SessionRegistry.swift:16-19` (flat); `TerminalWindowController.swift:127` (`setActivePane`, private); `PaneNode` `leaves()`/`contains` public |
| **D** | Copy-output vs visual selection; fork-free? | **Copy-to-clipboard, not visual select.** **Verifier: partial** — copy is *best-effort* fork-free (eager `getText` while at bottom, store the `String`); *robust* copy = +1 anchor accessor; *visual* select = +2 (second wall). | High | `Terminal.swift:5869` (`getText` public); `Position.swift:11`; `SelectionService.swift:16` (internal); `AppleTerminalView.swift:1902-1904` (selection cleared on output) |
| **E** | Upstream accept the accessors? Fork strategy? | **Likely merge-on-merits** (additive, mirrors public `getScrollInvariantLine`) but bus-factor-1 timing risk. **Don't fork now** (P5 needs none). At P4b: PR upstream **and** pin a revision fork in parallel. | Med-high | `Terminal.swift:743` (precedent); `XttyCore/Package.swift:23`; MIT, no `CONTRIBUTING.md` |
| **F** | SwiftUI refresh strategy? | **Event-driven `@Observable`** — the OSC handlers already run on the main actor (`MainActor.assumeIsolated`, shipped), so updates are synchronous with no marshalling. **One timer only**: `TimelineView(.periodic(by: 1))` scoped to running rows for the ticking duration. | High | `LocalProcess.swift:115` (feed on `.main`); `PaneController.swift:98,158` (assumeIsolated) |

### Details that shaped the plan

- **B is a two-for-one.** Capturing `rowAtC` at command-start (the future jump anchor) is the *same write* that closes the known running-block gap (`BlockState.running` is defined at `Block.swift:6` but never emitted; the in-flight command sits in private fields, appended only at `D`, `Block.swift:94`). Guard the capture with `!canScroll || scrollPosition >= 1.0` (the `>= 1.0` form is needed because `scrollPosition` returns an ambiguous `0` on the alt-screen / `yDisp<=0`). The only failure window is a contrived background `printf '\e]133;C'` with no keystroke and no scrolling output — accepted as best-effort.
- **D flipped via the adversarial verifier.** A finder claimed copy-output "isn't fork-free"; the verifier **partially refuted** that and won: copy-last-output *is* best-effort fork-free via an eager synchronous `getText(start:end:)` at C/D while auto-scrolled to bottom (where the public proxy `getCursorLocation().y + getTopVisibleRow()` equals the true buffer-index `y + yBase`). The internal anchor is needed **only** for a robust/scrolled-up version. Visual on-screen selection stays in P4b (second wall).
- **F's premise was moot.** No concurrency work — handlers are already main-actor (17 P4a e2e green). Sidebar state updates are synchronous; the only periodic work is the live-duration tick.

---

## P5 scope — `add-session-sidebar` (core-only, all fork-free)

**Prerequisite (one S change, unblocks the running dot + duration + future jump):** close the `BlockTracker` in-flight gap — emit `BlockState.running`, expose `runningBlock`/`startedAt`, and capture `rowAtC` at command-start (per B).

**Core:**
- `SessionActivity` enum in `XttyCore` (`idle / running / succeeded / failed / fullScreen`, + optional `waiting`); map `failed` ← last block exit ≠ 0, `fullScreen` ← `isAlternateScreen`, `running` ← the gap-fix.
- **Grouping: `Tab ▸ Pane`, key window** (user-confirmed). VM assembled by the coordinator from `windowControllers` + per-controller `tree.leaves()`; add a small public surface (`orderedPanes`, `owns(_:)`, tab title) to `TerminalWindowController`.
- Observation seam: `SessionRegistry` → `@Observable`, revision bump on register/unregister/focus; `BlockTracker.handle` publishes.
- Click → a new public `focusPane(id)` wrapping the existing `setActivePane(_:)` + `makeKeyAndOrderFront` (background-tab case). **Focus only — never scroll-to-row** (that would pull the fork forward).
- Live duration via per-running-row `TimelineView(.periodic(from: startedAt, by: 1))`, self-pausing when nothing runs (honors M1/M4).
- Doc fix: `xtty-requirements.md` H1 "blocked" → "failed" (xtty has no native needs-human signal).

**Deferred bonuses (not in the first P5 change, per the user's core-only call):** OSC 9;4 live progress via `registerOscHandler(code: 9)` (re-forward non-`4;`); best-effort "Copy output."

**Explicitly out of P5:** scroll-to-row / jump, gutter marks, visual selection, global cross-window sidebar, split-geometry mirroring, any `TerminalView`-internals access, any fork.

---

## Corrections folded into the docs

- ✅ **`xtty-requirements.md` H1** updated: "idle / working / done / **failed**" (was "blocked" — no native signal for it; the build plan had already silently swapped it).
- ❌ **OSC 9;4 via a delegate override is impossible.** `progressReport` on the Mac view is `public func`, **not `open`** (`MacTerminalView.swift:2283`) — unlike `bufferActivated` (`:554`, which xtty *does* override). The bonus progress channel must use a custom `registerOscHandler(code: 9, …)` in `XttyCore` (the proven OSC 133 pattern, `Terminal.swift:1054`), re-forwarding non-`4;` OSC 9 so notifications / the built-in bar aren't swallowed. The milestone "P5 bonus" text was corrected accordingly.

---

## Residual product calls (for the user / cheap spikes, not blockers)

- **[product] Is `failed` an acceptable proxy for the user's mental "blocked"?** xtty has no native needs-human signal. (Adopted `failed`; revisit only if true agent-waiting detection is wanted — a separate spike.)
- **[empirical] Do the user's real tools emit OSC 9;4?** Cheapest: run daily tools (Claude Code, npm, cargo, long builds) and `grep` the stream for `ESC]9;4;`. Common → promote `running(progress:)`/`waiting` to first-class; absent → keep them bonus-only.
- **[empirical] Real-world `rowAtC`-not-at-bottom rate.** Cheapest: add a DEBUG `atBottomAtLastC: Bool` to `writeStateDump()` and assert `true` in the injected-zsh e2e. Any `false` without manual scrolling flips B from "usually correct" to "needs defensive capture."
- **[timing] Upstream merge latency (bus factor 1).** Cheapest de-risk before P4b: glance at SwiftTerm's open-PR queue; a stale additive-PR queue → skip the upstream attempt and go straight to the pinned fork.

---

## Sources

- **Workflows** (this session, 2026-06-28): `p4b-directions-research` (5 readers → verify → synth) and `p4b-open-questions-research` (6 readers → 2 verifiers → synth), over local source; load-bearing access-level claims hand-verified by grep (cited inline).
- **SwiftTerm checkout** — `…/SourcePackages/checkouts/SwiftTerm/Sources/SwiftTerm`: `Terminal.swift`, `Buffer.swift`, `SelectionService.swift`, `Position.swift`, `Apple/AppleTerminalView.swift`, `Mac/MacTerminalView.swift`, `LocalProcess.swift`.
- **xtty** — `XttyCore/Sources/XttyCore/{Block,TerminalSession,Pane,PaneNode,SessionRegistry}.swift`, `App/{PaneController,TerminalWindowController,XttyTerminalView,QuickTerminalController}.swift`, `XttyCore/Package.swift`, `AppUITests/XttySemanticCaptureUITests.swift`.
- **Prior decisions** — [P4 semantic-capture decisions](p4-semantic-capture-decisions.md) (the data model + the coordinate gap this builds on), [requirements](xtty-requirements.md) (H1), [milestones](../04-design/02-milestones.md) (P4/P5).
