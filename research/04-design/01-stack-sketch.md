# `xtty` Stack Sketch

> **Provenance:** Drafted 2026-06-27 from the [requirements](../03-analysis/xtty-requirements.md), [internals](../02-internals/) research, and a design discussion. This is the **primary stack** (All-Swift) plus **alternative stacks** kept on file as researched fallbacks if we hit limitations. Nothing is built yet — this is a starting sketch, expected to evolve.

## Decisions locked

| Decision | Choice | Why |
|---|---|---|
| Core language / UI | **All-Swift** (Swift + SwiftUI/AppKit) | Fastest path to a real native macOS app; one language; Ghostty proves a Swift macOS frontend stays lean |
| Platform | **macOS-first** | Matches positioning; Metal + CoreText are first-class |
| Renderer | **Metal** (custom view), latency-first — *but staged* (see below) | Metal is the macOS dividing line; latency > throughput ([06-performance](../02-internals/06-performance-latency.md)) |
| **SwiftTerm adoption** | **Staged: start Level 3** (wrap SwiftTerm's `TerminalView`), drop to **Level 1** (own Metal renderer) only if measurement demands | Reuse now / control later; the engine seam is reversible (`getTerminal()` is public). See "Decision" under Spike findings. |
| Footprint | **Lean** (bound scrollback, manage atlas, no retain cycles) | Memory is an *architecture* problem, not a language one — Swift/ARC is lean |
| Distribution | **Free / open, no account, no paywall** | [xtty-requirements](../03-analysis/xtty-requirements.md) M1–M3 |

**On memory:** Swift uses ARC (no GC, no VM) — baseline footprint is native-app small. Warp's heaviness is leaks + custom UI + cloud (it's Rust, not a language problem); Electron terminals are heavy because of Chromium. Real memory drivers in *any* terminal: scrollback size, glyph atlas, images, pane count. The one Swift-specific caveat is avoiding strong reference cycles (`weak`/`unowned`).

---

## Primary stack — All-Swift

```
┌──────────────────────────────────────────────┐
│  SwiftUI / AppKit  — window chrome, tabs,     │
│                      session sidebar, file/diff│
│  ┌────────────────────────────────────────┐  │
│  │  Custom Metal view (MTKView/CAMetalLayer)│ │  ← hot render path,
│  │  glyph atlas (CoreText) + instanced draw │ │    bypasses SwiftUI
│  └────────────────────────────────────────┘  │
└───────────────┬──────────────────────────────┘
                │ screen grid (rows × styled cells)
┌───────────────┴──────────────────────────────┐
│  VT engine — parser (Williams FSM) + grid     │  ← reuse SwiftTerm core
│  + scrollback + OSC 7/133 capture             │
└───────────────┬──────────────────────────────┘
                │ bytes
┌───────────────┴──────────────────────────────┐
│  PTY layer — posix_openpt/forkpty, kqueue     │
│  read/write loop, TIOCSWINSZ/SIGWINCH         │
└───────────────┬──────────────────────────────┘
                │
            shell (zsh) on the slave PTY
```

### Components

| Layer | Choice | Notes |
|---|---|---|
| **UI / chrome** | SwiftUI + AppKit | Native menus, windows, tabs. Use AppKit where SwiftUI is limiting (text input, NSView hosting). |
| **Renderer** | Custom `MTKView`/`CAMetalLayer` + Metal | Cell grid, glyph atlas rasterized via CoreText, instanced draws, damage tracking, dedicated render thread. See [03-gpu-rendering-metal](../02-internals/03-gpu-rendering-metal.md). |
| **VT engine** | **Reuse — SwiftTerm core** (Miguel de Icaza, MIT) | Use its headless `Terminal` engine (parser + grid) and render ourselves with Metal rather than using its bundled views. Correct on day one; avoids hand-rolling the Williams FSM. See [02-vt-ansi-parsing](../02-internals/02-vt-ansi-parsing.md). |
| **PTY** | Darwin `posix_openpt`/`grantpt`/`unlockpt`/`ptsname` or `forkpty` (SwiftTerm also ships a `LocalProcess` helper) | kqueue-driven loop; chunk writes (macOS ~1024-byte canonical buffer); handle SIGWINCH. See [01-pty-fundamentals](../02-internals/01-pty-fundamentals.md). |
| **Fonts** | CoreText (native) | Shape in style-batched runs for ligatures; grayscale AA + correct gamma; wide/emoji 2-cell handling. See [04-fonts](../02-internals/04-fonts-text-shaping.md). |
| **Shell integration** | OSC 7 + OSC 133 capture, auto-injection + fallback | Foundation for the session sidebar, jump-to-prompt, failed-command marks, and future agents. See [agents-and-xtty](../03-analysis/agents-and-xtty.md). |
| **Differentiator features** | Session-progress sidebar (H1), file/diff view (H2) | Built in SwiftUI on top of OSC capture; file/diff is lightweight (not a full IDE). |

### Threading (latency-first)
Separate **read** (PTY → parser), **render** (grid → Metal, vsync-aligned), and **main/UI** concerns so PTY draining never blocks frames and vice versa — the throughput-vs-latency split from [06-performance](../02-internals/06-performance-latency.md).

### VT engine: reuse vs build
- **Primary = reuse (SwiftTerm).** Ship a correct terminal fast; spend effort on the visible differentiators.
- **Learning option = build from scratch.** Hand-write the Williams FSM + grid. Slower, more edge cases (UTF-8/C1 collision, split sequences, `wcwidth`), but deep understanding — valid since this began as an exploration project. Could also be a *later* swap: start on SwiftTerm, replace with an in-house engine once the GUI is solid.

---

## Alternative stacks (researched fallbacks)

Kept on file so we have a direction if we hit a limitation. Each lists **when you'd switch** and **what to research next**.

### Alt A — Rust core + Swift GUI
- **Shape:** Rust VT/grid core (alacritty/`vte` crate) + OSC + PTY, exposed via a **C-ABI**, with a Swift/SwiftUI/Metal frontend.
- **When you'd switch:** you want max performance headroom; you decide to go **cross-platform** (the Rust core ports to Linux/Windows); SwiftTerm's data model becomes limiting.
- **Cost:** an FFI boundary to design/maintain, two languages, more build setup.
- **Future research:** C-ABI patterns (cf. `libghostty`), `vte` crate API, threading across the FFI line, `portable-pty`.

### Alt B — Zig core + Swift GUI (the Ghostty model)
- **Shape:** Zig VT/render core (or embed **libghostty** directly via its C-ABI) behind a native Swift macOS app.
- **When you'd switch:** you want a proven, SIMD-optimized core and an embeddable engine; you're willing to invest in Zig.
- **Cost:** Zig is the youngest ecosystem, steepest learning curve.
- **Future research:** `libghostty` / `libghostty-vt` embedding, Ghostty's read/write/render thread design, Zig interop with Swift.

### Alt C — Embed `libghostty` from All-Swift (hybrid shortcut)
- **Shape:** Stay All-Swift for everything *except* the VT core, which is `libghostty-vt` (C-ABI) instead of SwiftTerm.
- **When you'd switch:** SwiftTerm proves too slow/limited but you don't want to adopt Rust/Zig as a primary language.
- **Cost:** a C-ABI dependency to track; less Swift-pure.
- **Future research:** libghostty-vt's C API surface, build/linking from a Swift package.

### Quick comparison

| | Native feel | Perf headroom | Cross-platform later | Languages | Learning curve |
|---|---|---|---|---|---|
| **Primary: All-Swift + SwiftTerm** | ★★★ | ★★ | ★ | 1 | low |
| Alt A: Rust core + Swift | ★★★ | ★★★ | ★★★ | 2 | medium |
| Alt B: Zig core + Swift | ★★★ | ★★★ | ★★★ | 2 | high |
| Alt C: Swift + libghostty-vt | ★★★ | ★★★ | ★★ | 1 (+C dep) | low–medium |

---

## Spike findings (2026-06-27)

> Resolved the two open unknowns by reading SwiftTerm's source (cloned `migueldeicaza/SwiftTerm`, MIT, v1.13.0 / Mar 2026) and Apple's sandbox/notarization docs. Both resolved favorably; one surfaced a bigger discovery.

### Finding 1 — Reusing SwiftTerm as a headless engine is ✅ validated (and it does far more than parse)
The engine is genuinely UI-agnostic and the per-cell read path we need exists and is public:
- **Feed:** `Terminal.feed(byteArray:)` / `feed(text:)` / `feed(buffer: ArraySlice<UInt8>)`
- **Read grid:** `Terminal.getCharData(col:row:) -> CharData?`, `getLine(row:) -> BufferLine?`, `getScrollInvariantLine(row:)`; `BufferLine` exposes `subscript(i) -> CharData`, `.count`, `.getData() -> [CharData]`, `.getWidth(i)`
- **Cell model:** `CharData` → `.getCharacter()`, `.width: Int8`, `.attribute: Attribute`; `Attribute` → `.fg`/`.bg` (`Color`: ANSI/256/TrueColor), `.style: CharacterStyle` (bold/italic/underline/blink/inverse/invisible/dim/crossedOut), `.underlineStyle`, `.underlineColor`
- **Dims/resize/damage:** `Terminal.cols`/`rows`, `resize(cols:rows:)`, `getScrollInvariantUpdateRange() -> (startY,endY)?` (enables damage-tracked redraws), `sendResponse(...)` for replies; dedicated `HeadlessTerminal` class for no-UI use.

**Bigger discovery — SwiftTerm is a near-complete terminal, not just a parser.** Its sources already include:
- a **Metal renderer** (`Apple/Metal/MetalTerminalRenderer.swift`, ~2,780 LOC, `MTKViewDelegate`-based) with **grayscale + BGRA glyph atlases**, a **CoreText glyph rasterizer**, ligature shaper cache, image batches, and a buffer pool — but it is **experimental and opt-in** (`MacTerminalView` defaults `useMetalRenderer = false`).
- **PTY/process** (`LocalProcess`, `Pty`, `MacLocalTerminalView`), **graphics protocols** (Kitty + Sixel), **kitty keyboard**, and **search**.
- A SwiftUI wrapper exists but is **iOS-only** (`UIViewRepresentable`); a macOS SwiftUI host is a trivial `NSViewRepresentable` we'd add.

**Implication — a new decision this raises (see Open questions):** *how much* of SwiftTerm to adopt. Three levels: (1) **engine only** → write our own Metal renderer (max control, most work; SwiftTerm's renderer is a great reference/vendoring source); (2) **engine + its Metal renderer**; (3) **its full `TerminalView`** wholesale, building the sidebar/file-diff/OSC features around it (fastest to a working terminal; least control; Metal path still experimental). This materially affects milestones P2–P6.

**Fallback unchanged:** `libghostty-vt` is real and capable (zero-dep, scrollback/wrap/reflow, macOS/Linux/Windows/WASM) but its **API/ABI is explicitly in flux and unversioned** — so it stays Alt-C, not a now-choice.

### Finding 2 — Sandbox / entitlements for spawning a shell is ✅ clarified
**App Sandbox and Hardened Runtime are independent switches** (the common confusion):
- **App Sandbox** — required only for the **Mac App Store**; *optional* for Developer ID. A sandboxed terminal is crippled (child procs inherit the sandbox; file access limited). → **xtty: OFF.**
- **Hardened Runtime** — required for **notarization** (= Developer ID distribution), separate from sandbox, and it does **not** block spawning child processes. → **xtty: ON, but only matters at P10.**
- A **non-sandboxed** app spawns `/bin/zsh` and reads the user's files with normal Unix privileges — **no special entitlement needed.**
- Milestone mapping: **P0** = set Sandbox OFF + "Sign to Run Locally"; **P1** = spawn shell works as-is; **P10** = add Hardened Runtime + Developer ID + notarize.

### Decision (2026-06-27) — SwiftTerm adoption: **staged, start at Level 3**

The spike found the three "adoption levels" are **one engine with different render skins**, and the engine is always reachable (`TerminalView.getTerminal() -> Terminal` is public). So the choice is reversible, and the reuse-vs-control tension can be resolved by *measurement* rather than guessing.

```
   Level 1  engine + OUR Metal renderer + own input/selection   (max control, most work)
   Level 2  engine + SwiftTerm's Metal renderer                 (awkward: experimental +
            └─ NOT a distinct target — coupled to MacTerminalView;  coupled → folds into L1/L3)
   Level 3  engine + SwiftTerm's full TerminalView (AppKit)      (fastest to daily-driver;
            selection/input/scrollback/search/graphics = done)      least render control)
```

**Decision:** **Start at Level 3.** Wrap SwiftTerm's `TerminalView` / `LocalProcessTerminalView` in an `NSViewRepresentable`; build xtty's differentiators (tabs/splits, OSC 133 blocks, session sidebar, file/diff) around it. **Drop to Level 1** (own Metal renderer, keeping the same engine) **only if** measured latency/memory misses M1/M4 — first trying the experimental `useMetalRenderer` flag and frame-pacing tuning.

**Why:** satisfies both AGENTS.md conventions *in sequence* — "reuse battle-tested components" now, "latency/low-memory control" later if data demands. Matches "thin vertical slice first" and "measure before changing."

**Load-bearing rule (P0):** all differentiator logic talks to the **`Terminal` engine**, never to `TerminalView` internals — so the render layer stays swappable (the `XttyCore` seam). L3→L1 then becomes a contained render-layer refactor, not a rewrite.

**Bonus capabilities already free at any level:** OSC 7 cwd (`hostCurrentDirectoryUpdated`), OSC 9;4 **progress** (`progressReport` + `Terminal.ProgressReport` — direct fuel for the sidebar), Kitty/Sixel graphics, hyperlinks, clipboard, search. OSC 133 is added in one call: `terminal.registerOscHandler(code: 133, …)`.

## Risks & triggers to revisit this sketch

- **SwiftTerm limitations** (perf, data model, maintenance) → consider Alt C (libghostty-vt) or Alt A.
- **Cross-platform demand** → Alt A or Alt B (portable core).
- **Latency not good enough** → revisit render-thread design + frame pacing before changing language ([06-performance](../02-internals/06-performance-latency.md)).
- **Memory creeping up** → check scrollback cap, atlas eviction, retain cycles *before* blaming the stack.

## Open questions (for later)
- ~~SwiftTerm adoption level~~ → **RESOLVED**: staged, start Level 3 (see Decision above). Milestones re-mapped in [02-milestones](02-milestones.md).
- Scrollback default + cap; reflow strategy on resize ([07-multiplexing](../02-internals/07-multiplexing-sessions.md)). (SwiftTerm handles scrollback/reflow; libghostty-vt also does.)
- Graphics protocol support (kitty/iTerm2/Sixel) — likely **free via SwiftTerm** ([05-graphics-protocols](../02-internals/05-graphics-protocols.md)).
- Splits/tabs model and whether to offer a Quick-Terminal dropdown (N3).
- Agent-drivable local API shape (N1) — model on [Herdr](../03-analysis/adjacent-tools.md)'s socket API.

## Related
- [xtty requirements](../03-analysis/xtty-requirements.md) · [agents-and-xtty](../03-analysis/agents-and-xtty.md) · [opportunities](../03-analysis/opportunities.md)
- Internals: [PTY](../02-internals/01-pty-fundamentals.md) · [VT parsing](../02-internals/02-vt-ansi-parsing.md) · [GPU/Metal](../02-internals/03-gpu-rendering-metal.md) · [fonts](../02-internals/04-fonts-text-shaping.md) · [performance](../02-internals/06-performance-latency.md)
