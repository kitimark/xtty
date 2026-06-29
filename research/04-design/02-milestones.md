# `xtty` Phased Build Plan

> **Provenance:** Drafted 2026-06-27 from the [stack sketch](01-stack-sketch.md), [requirements](../03-analysis/xtty-requirements.md), and [internals](../02-internals/) research. **Re-mapped 2026-06-27** to the **SwiftTerm adoption decision: staged, start at Level 3** (see the stack sketch's Spike findings → Decision). Earlier drafts assumed a build-it-ourselves renderer; that work is now deferred to a *conditional* late phase.

## Principle: reuse the engine + view, build the differentiators

Starting at **Level 3** (wrap SwiftTerm's `TerminalView`), the PTY loop, VT parsing, rendering, input, selection, scrollback, search, and graphics protocols are **already done**. So the early milestones collapse into "integrate & configure," and real effort moves up to what makes xtty *xtty*: tabs/splits, OSC 133 blocks, the session sidebar, and the file/diff view.

**The load-bearing rule (set at P0):** all xtty logic talks to the **`Terminal` engine** (`view.getTerminal()`), never to `TerminalView` internals — so the render layer stays swappable and the L3→L1 escape hatch (P8) is a contained refactor, not a rewrite.

Requirement tags reference [xtty-requirements](../03-analysis/xtty-requirements.md) (M = must-have, H = high-value, N = nice-to-have).

---

## Phase 0 — Skeleton + the seam  ·  M2, M3  ✅ **done** (`add-app-skeleton`, archived)
**Goal:** a buildable native macOS app with the architecture's seam drawn.
- Xcode app (or generated project) + window; **App Sandbox OFF**, "Sign to Run Locally."
- Stand up **`XttyCore`** as a local SPM package (near-empty) — the engine-facing seam.
- Add **SwiftTerm** as a dependency.

**Done when:** the app launches an empty window and `swift build` is green.
**Refs:** [stack sketch](01-stack-sketch.md); sandbox detail in its Spike findings.

## Phase 1 — Integrate SwiftTerm → a working terminal  ·  M5, M6 *(collapses old P1–P3)*  ✅ **done** (`integrate-swiftterm`)
**Goal:** a real, interactive terminal, fast.
- Wrap SwiftTerm's `LocalProcessTerminalView` (PTY + view) in an `NSViewRepresentable`, hosted in the SwiftUI window.
- Spawn `zsh`; confirm input/resize/paste/selection/scrollback all work (SwiftTerm provides these).
- Expose the underlying `Terminal` via `getTerminal()` through `XttyCore` (enforce the seam now).

**Done when:** you can run `vim`/`htop`, resize, paste multi-line, scroll back, and select text — no corruption.
**Refs:** [01-pty-fundamentals](../02-internals/01-pty-fundamentals.md), [02-vt-ansi-parsing](../02-internals/02-vt-ansi-parsing.md)
**Note:** this single phase replaces the old "hello-PTY → VT engine → input/resize" sequence — all free via SwiftTerm.
**Shipped as:** the view is hosted in an **AppKit `NSWindow`**, *not* the planned SwiftUI `NSViewRepresentable` — SwiftTerm renders black under SwiftUI hosting on macOS 26 (both CoreGraphics and Metal paths). The window opens on the built-in display. See [`integrate-swiftterm/design.md`](../../openspec/changes/integrate-swiftterm/design.md). Interactive behaviors verified hands-on + via the XCUITest harness ([`add-verification-harness`](../../openspec/changes/add-verification-harness/design.md), [native-app testing tooling](../03-analysis/native-app-testing-tooling.md)).

## Phase 2 — Daily-driver baseline  ·  M5 *(collapses old P4–P5)*  ✅ **done** (`add-daily-driver-baseline`)
**Goal:** good enough to use every day — mostly *configure & verify*, not build.
- ✅ Font/size/theme config via `~/.config/xtty/config` (view-free loader in `XttyCore`); live Cmd +/−/0 font sizing. Confirmed 24-bit truecolor + wide/emoji (CJK 日本語, 🚀✅) via the harness; **ligatures are a no-op** in SwiftTerm's grid path (see [Metal spike note](../03-analysis/swiftterm-metal-renderer-spike.md)).
- ✅ Bounded **scrollback cap** (default 10 000 / ceiling 100 000), asserted saturating under a flood; Cmd+F find bar wired + verified.
- ✅ Evaluated SwiftTerm's experimental `setUseMetal` — works in the AppKit host; adoption deferred to the P7 latency gate ([spike note](../03-analysis/swiftterm-metal-renderer-spike.md)).

**Done when:** you switch your own daily terminal to xtty and it doesn't annoy you.
**Refs:** [04-fonts](../02-internals/04-fonts-text-shaping.md), [05-graphics-protocols](../02-internals/05-graphics-protocols.md) (Kitty/Sixel already supported)

## Phase 3 — Native shell UX  ·  M6, N3  *(✅ complete — P3a + P3b implemented & archived)*
**Goal:** the multiplexing/native conveniences SwiftTerm's single view doesn't provide.
- ✅ **P3a (`add-tabs-and-splits`)** — native **tabs** (native `NSWindow` tabbing, Ghostty-style) + custom **splits/panes** (`NSSplitView` tree over a view-free `XttyCore` pane model) + multiple windows + unified close/exit escalation; **configurable keybindings** (`iterm`/`ghostty` presets + per-action overrides); clickable URL links (SwiftTerm-inherited; non-`http(s)` guard deferred). 52 unit + 12 UI tests green.
- ✅ **P3b** — Quick-Terminal dropdown (`add-quick-terminal`: global-hotkey quake panel, view-free `HotKeyParser`, accessory/private-registry exclusion) **and** profiles (`add-profiles`: named `[profile "name"]` bundles inheriting base, login-shell `command` wrap + `cwd` + additive `env`, per-pane profile identity + split inheritance, "New Tab with Profile" menu, quake on base, `confirm-close`; 91 unit + 14 UI tests green); **file:line error-matching deferred to P4** (needs OSC 7 cwd). Decisions: [`p3b-shell-ux-decisions`](../03-analysis/p3b-shell-ux-decisions.md).

**Done when:** tabs + splits feel native and stable. *(P3a meets this; P3b adds the extras.)*

## Phase 4 — Semantic capture / blocks  ·  H3 *(keystone — old P7)*  *(P4a + P4b-1 ✅ archived; P4b-2 ✅ implemented & lit up — pending archive)*
**Goal:** the foundation for every differentiator. **Split into P4a (data model, fork-free) + P4b-1 (`add-file-link-open`, file:line click-to-open — fork-free) + P4b-2 (`add-spatial-blocks`, jump/copy spatial ops — needs a SwiftTerm fork)** — see [`p4-semantic-capture-decisions`](../03-analysis/p4-semantic-capture-decisions.md) and the [P4b split](../03-analysis/p5-sidebar-and-p4b-sequencing.md#update-2026-06-28-post-p5-p4b-splits-in-two--fileline-click-to-open-is-fork-free).
- ✅ **P4a (`add-semantic-capture`)** — **OSC 7 cwd** captured via the (now wired) `hostCurrentDirectoryUpdate` delegate, decoded (`file://`/`kitty-shell-cwd://`, remote-host flag); new **splits open in the focused pane's live cwd**. **OSC 133** registered on the engine (`registerOscHandler(code: 133)`); a view-free parser (A/B/C/D/P, bare-positional exit code, `cmdline`/`cmdline_url`, `k=s`) feeds a view-free **block-lifecycle state machine** + per-session `BlockTracker` (command/exit/cwd/timestamps/state — **no fragile row coordinates**). **Auto-injects zsh** integration via `ZDOTDIR` redirection (bundled `.zshenv` restores the user's config; additive hooks coexist with p10k/starship; skipped for `command` one-shots; manual fallback documented). **Alt-screen gating** via an `open bufferActivated` override + public `isCurrentBufferAlternate` (full-screen apps → `opaque`, never normal blocks; OSC 133 best-effort, tmux/ssh degrade to plain output). 126 `XttyCore` unit + 17 XCUITests green (the block/cwd e2e drives a real injected zsh).
- ✅ **P4b-1 (`add-file-link-open`, FORK-FREE — the agent-CLI half)** — implemented **and archived**. **file:line click-to-open**: Cmd-click a `path:line:col` (or bare/relative/rooted path) → opens in the user's editor at that line, resolved against the pane's live cwd (P4a). Plus the **P3b/D7-deferred scheme guard** (only `http`/`https`/`mailto` auto-open; other schemes blocked). Fork-free: SwiftTerm's implicit link detection is default-on (`linkReporting = .implicit`) and its ported Ghostty matcher detects bare/relative paths + `:line`. Interception is a **vetted `terminalDelegate` proxy** (`requestOpenLink` is not forwarded to `processDelegate` and its protocol-extension default can't be subclass-overridden — design D1, not the naive delegate the explore assumed). View-free `LinkOpen.swift`/`LinkRouter` (classify→guard→resolve→build) + `link-opener` config key; `FileOpener` execs via login-shell PATH with the path as a literal argv (D4). 148 `XttyCore` unit + 20 XCUITests green. Feeds the **P6 file/diff view**. Evidence: [P4b split](../03-analysis/p5-sidebar-and-p4b-sequencing.md#update-2026-06-28-post-p5-p4b-splits-in-two--fileline-click-to-open-is-fork-free).
- ✅ **P4b-2 (`add-spatial-blocks` — the in-terminal-nav half)** — implemented & lit up (pending archive). **Jump-to-prompt** (Cmd+Shift+↑/↓) + **copy-command-output** (Cmd+Shift+C, engine-only `getText`→clipboard, prompt excluded, + a toast). Built on a **2-accessor** SwiftTerm addition (`getScrollInvariantCursorLocation` + `scrollbackBase`) shipped via a **gitignored clone + `git apply`'d `.diff` (no fork repo)** — `scripts/bootstrap-swiftterm.sh`, pinned via `UPSTREAM_CONFIG.sh`; see [fork vs patch](../03-analysis/swiftterm-fork-vs-patch-strategy.md). Best-effort anchors captured at OSC-133 A/C/D, invalidated on resize (`sizeChanged`→epoch) + clear (`liveTop` drop), validated at use; everything degrades gracefully (no-op) without anchors. **Tier-2 visual-select deferred** (forks the view, P7-gated); **gutter marks dropped** (P5 sidebar). 162 `XttyCore` unit + 23 XCUITests green. Decisions: [`p4b-2-spatial-blocks-decisions`](../03-analysis/p4b-2-spatial-blocks-decisions.md).

**Done when (P4a):** new splits open in the right cwd; commands are captured as blocks with exit codes + state (failed marked); full-screen apps don't become blocks; integration is automatic for zsh. **(P4b-1 adds fork-free file:line click-to-open; P4b-2 adds the fork-gated jump/copy affordances — both after P5.)**
**Refs:** [08-modern-innovations](../02-internals/08-modern-innovations.md), [agents-and-xtty](../03-analysis/agents-and-xtty.md), [p4 decisions](../03-analysis/p4-semantic-capture-decisions.md)
**Risks (handled in P4a):** fragile prompt hooks (Starship/p10k) → additive `add-zsh-hook`; tmux/ssh passthrough → best-effort degrade to no-blocks; alt-screen apps NOT chopped into blocks → `bufferActivated` gating.

## Phase 5 — Session-progress sidebar  ·  H1 *(the favorite feature — old P8)*  *(✅ `add-session-sidebar` implemented — pending archive)*
**Goal:** at-a-glance per-session state — what you liked most in Warp. **Fully fork-free on P4a's block model.** Scope settled in [`p5-sidebar-and-p4b-sequencing`](../03-analysis/p5-sidebar-and-p4b-sequencing.md).
- **Prerequisite (one small `XttyCore` change):** close the `BlockTracker` in-flight gap — emit `BlockState.running`, expose the running block + `startedAt` (today blocks are appended only at the closing OSC 133 `D`). Capture `rowAtC` here too (the future jump anchor — same write).
- SwiftUI sidebar as a **`Tab ▸ Pane` tree** (key window), with a session-level state enum `idle / running / succeeded / failed / fullScreen`, from OSC 133 boundaries + exit codes + `isAlternateScreen`.
- Click → **focus the pane** (reuse the existing `setActivePane`); **not** scroll-to-row (that would pull the P4b fork forward). Show last command / live duration (`TimelineView(.periodic(by: 1))` scoped to running rows).
- Updates are **event-driven** (`@Observable`; the OSC handlers already run on the main actor — no marshalling).
- **Bonus (deferred, not in the first change):** OSC 9;4 progress (`.set`/`.pause`/`.error`). ⚠️ **Cannot** be captured by overriding `progressReport` — it is `public`, not `open` — so use a custom `registerOscHandler(code: 9)` in `XttyCore`, re-forwarding non-`4;` OSC 9. Best-effort "Copy output" is the other deferred bonus.

**Done when:** you glance at the sidebar and see what each terminal is doing.
**Refs:** [adjacent-tools (Herdr)](../03-analysis/adjacent-tools.md) (state-sidebar model); [P5/P4b sequencing](../03-analysis/p5-sidebar-and-p4b-sequencing.md)

## Phase 6 — File / diff view  ·  H2 *(the Zed habit — old P9)*  *(✅ P6a `add-git-review` implemented + archived · 📋 P6a+ `add-git-review-polish` proposed — ready to apply)*
**Goal:** lightweight in-terminal **git review before commit** — *not* a full IDE (non-goal). **Split into P6a (git-review panel, lead) + P6a+ (intra-line emphasis polish, decided) + P6b (full file-tree browser, deferred)** — see [`p6-file-diff-decisions`](../03-analysis/p6-file-diff-decisions.md).
- ✅ **P6a — read-only git-review panel (`add-git-review`, implemented + archived):** a `git status`-derived changed-files list (grouped Changes / Untracked / Conflicts) → click-to-diff, a plain **unified** diff in SwiftUI; in a new collapsible **right-edge** panel (left edge stays the P5 session sidebar); ⌘-click a file → open in editor (reuses P4b-1). Git via **shell-out** (no libgit2); cwd from P4a's OSC 7 (`liveLocalDirectory`). Refresh on OSC-133 command-finish **+ a ~5 s gated poll backstop** (catches an agent editing *mid*-command) — the "review what the agent changed, then commit" surface. 185 `XttyCore` unit + 25 XCUITests green.
- 📋 **P6a+ — intra-line diff emphasis (`add-git-review-polish`, proposed — ready to apply):** **token-level** word-diff emphasis on the unified diff (tokenize → small LCS/DP over tokens → highlight changed spans via `Text(AttributedString)` per-run background, macOS 12+, no fallback), gated zed/delta-style (≤5 lines / 512 bytes / 1:1 pairing / ratio-gate), pure `XttyCore` + one render swap, zero new deps; bundles a one-line **pause-during-own-git** poll guard. Defers syntax highlighting, FSEvents, unbalanced-run emphasis. See the [P6a+ addendum](../03-analysis/p6-file-diff-decisions.md#p6a-addendum--intra-line-diff-emphasis-decided-add-git-review-polish).
- **P6b — full project file-tree browser (deferred / optional):** browse *all* files (lazy tree, expand/collapse). The `git status` list already gives a scoped file view, so the tree is a convenience, not the keystone.
- **Out of scope (read-only bet):** staging / commit / discard — every comparable tool is read-write, but xtty stays read-only for leanness and pairs with `lazygit`; the data model stays forward-compatible with a later stage toggle.

**Done when (P6a):** you can glance at what changed in the focused pane's repo and read each file's diff without leaving xtty — and ⌘-click a changed file to open it at the line.
**Refs:** [p6 file/diff decisions](../03-analysis/p6-file-diff-decisions.md); reuses P4a cwd + P4b-1 click-to-open.

## Phase 7 — Polish + MEASURE (decision gate)  ·  M1, M4 *(old P10)*
**Goal:** verify the lean + fast requirements with data — this gates Phase 8.
- **Measure** key-to-photon latency and memory (scrollback + atlas + panes) against M1/M4.
- If short: first flip `useMetalRenderer` + tune frame pacing (cheap); re-measure.
- Memory pass: scrollback cap, retain-cycle/leak audit (Instruments). Crash hardening.
- **Hardened Runtime + Developer ID + notarization** for distribution.

**Done when:** footprint is lean and typing feels instant — OR you've decided Phase 8 is needed.
**Refs:** [06-performance](../02-internals/06-performance-latency.md), [xtty-requirements](../03-analysis/xtty-requirements.md)

## Phase 8 — *(conditional)* Drop to Level 1: own Metal renderer  ·  M4
**Goal:** only if Phase 7 measurement misses the bar after cheap fixes.
- Replace SwiftTerm's view with an `MTKView`/`CAMetalLayer` renderer reading the **same engine** (`getCharData`/`getLine`/`CharData`), with glyph atlas (CoreText), instanced draws, damage tracking (`getScrollInvariantUpdateRange`), dedicated render thread.
- SwiftTerm's own `MetalTerminalRenderer` is the reference/vendoring source.

**Done when:** latency/memory meet M1/M4. **Skip entirely if Phase 7 already passes.**
**Refs:** [03-gpu-rendering-metal](../02-internals/03-gpu-rendering-metal.md)

---

## Later / opt-in (post-MVP)
- **Agent-drivable local API** (N1) — read/send/wait/split over a socket; model on [Herdr](../03-analysis/adjacent-tools.md).
- **Pluggable / BYOK + local-model AI**, off by default (N2).
- Graphics protocols are **already supported** (Kitty/Sixel) — just surface/polish.
- Reflow-on-resize refinement (engine handles the basics); tmux-control-mode-style integration (stretch).

## Suggested MVP line
**Phases 0–2 = a usable terminal** (much faster than the old plan — days/weeks). **Phases 0–5 = an xtty that's distinctly yours** (lean, native, with the session sidebar). Phase 6 = the editor-adjacent extra. Phase 8 is a *conditional* escape hatch, not default work.

## Critical path & dependencies
```
P0 → P1 → P2 → P3
              └→ P4 (keystone) → P5 (needs P4)
                                 P6 (needs P4 cwd)
P7 (measure) spans P1–P6  ──gate──▶  P8 (only if needed)
```
P4 (OSC capture) is the keystone — P5 and P6 depend on it. P8 is reachable cheaply *because* of the P0 engine seam.

## Related
- [Stack sketch](01-stack-sketch.md) (esp. Spike findings → Decision) · [requirements](../03-analysis/xtty-requirements.md) · [agents-and-xtty](../03-analysis/agents-and-xtty.md)
