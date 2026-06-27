# SwiftTerm Metal renderer — P2 spike (evaluate, don't adopt)

> **Provenance:** Hands-on spike on 2026-06-28 during P2 (`add-daily-driver-baseline`, task 7). Toggled SwiftTerm's experimental Metal path behind a throwaway `-SpikeMetal` DEBUG flag in xtty's AppKit `NSWindow` host, drove truecolor/emoji/CJK output, and captured a screenshot on the built-in display. macOS 26.2, Xcode 26.6, SwiftTerm pinned in `Package.resolved`, Apple Silicon. The throwaway flag was removed after the finding was recorded; the default renderer is unchanged (CoreGraphics).

> _Topic scope:_ Does SwiftTerm's built-in GPU (Metal) renderer work in xtty's host today, and should we adopt it now? Background on GPU terminal rendering generally is in [GPU Rendering & Metal](../02-internals/03-gpu-rendering-metal.md).

## Question

xtty hosts SwiftTerm's `LocalProcessTerminalView` directly in an AppKit `NSWindow` because SwiftUI's `NSViewRepresentable` host renders SwiftTerm **black** on macOS 26 — for both the CoreGraphics *and* the Metal (`CAMetalLayer`) paths (see `TerminalWindowController`'s class-doc rationale). The latency-first goal (custom Metal view, frame pacing > throughput) raises the question for P2: **can we get a GPU path from SwiftTerm itself, and is it ready?** SwiftTerm exposes `public func setUseMetal(_:) throws` + `isUsingMetalRenderer` (`Mac/MacTerminalView.swift:247`), Metal **off by default**.

## Method

Throwaway DEBUG hook in `TerminalWindowController.init`, after the view is in the window (a documented precondition of `setUseMetal`):

```swift
if ProcessInfo.processInfo.arguments.contains("-SpikeMetal") {
    try terminal.setUseMetal(true)   // logs isUsingMetalRenderer
}
```

Launched `xtty -SpikeMetal`, confirmed `isUsing=true` in the log, then pasted a line exercising 24-bit truecolor (SGR `38;2;…`), emoji (🚀 ✅), wide CJK (日本語), and `ls` (ANSI-colored dir listing). Screenshot captured from the built-in display.

## Findings

- ✅ **The Metal path renders correctly in xtty's AppKit `NSWindow` host — not black.** Dark theme, truecolor orange, 🚀/✅, wide CJK 日本語, and ANSI-colored `ls` all rendered cleanly with no visible artifacts. This is the key result: P1's black-render was **specific to SwiftUI hosting**; the AppKit host composites SwiftTerm's `MTKView` subview fine. So the AppKit-hosting decision (P1) also **unblocks the GPU path** — we are not boxed into CoreGraphics.
- ✅ **`setUseMetal(true)` succeeds and is stable.** No crash; `isUsingMetalRenderer == true`. Requires the Metal Toolchain (already a build prerequisite — SwiftTerm bundles a `.metal` shader; see `AGENTS.md → Building`) and must be called **after** the view is in a window.
- ❓ **Latency / scroll smoothness vs CoreGraphics: not measured.** xtty has no key-to-photon or frame-pacing instrumentation yet, so the comparison was purely subjective (interaction felt responsive and visually identical). A rigorous A/B belongs at the **P7 latency measurement gate**, not here.
- ⚠️ **SwiftTerm marks this path experimental.** Source comment: *"Experimental GPU path: CoreText glyph atlas + Metal quads. Limitations: image caching is basic; GPU path is still evolving"* (`Mac/MacTerminalView.swift:119-120`). Not production-default material yet.
- ℹ️ **Ligature aside (P2 task 6.3):** SwiftTerm's grid path applies no ligature substitution to the monospaced cell grid (ligatures aren't modeled in the grid at all — confirmed in the harness recon), so ligatures are a **no-op for P2 regardless of renderer**. Programming-ligature support, if ever wanted, is a font/shaping feature to design separately.

## Decision

**Leave the default renderer as CoreGraphics (unchanged).** Per the milestone plan, the renderer decision is gated on P7 measurements, not vibes. This spike's value is **de-risking**: it proves SwiftTerm's GPU path is *available and functional* in our host today, so when P7 arrives we have two concrete options to measure against the CoreGraphics baseline:

1. **SwiftTerm's built-in Metal renderer** (`setUseMetal(true)`) — zero new rendering code, but experimental and tied to SwiftTerm's atlas/caching maturity.
2. **xtty's own custom Metal view** (the All-Swift stack's latency-first renderer — see [stack sketch](../04-design/01-stack-sketch.md)) — more work, full control over frame pacing.

Revisit at the P7 gate with real key-to-photon and scroll-throughput numbers.

## Sources

- SwiftTerm `Mac/MacTerminalView.swift`: `useMetalRenderer` (121), `isUsingMetalRenderer` (139), `setUseMetal(_:)` (247), `updateMetalRenderer` (260), experimental-path comment (119-120). Pinned revision per `Package.resolved`.
- Spike screenshot (built-in display, 2026-06-28) — retained in the session scratchpad.
- Build prereq (Metal Toolchain): `AGENTS.md → Building`.
- Milestone P7 (renderer gate): [`research/04-design/02-milestones.md`](../04-design/02-milestones.md).
- Related: `TerminalWindowController` class doc (SwiftUI black-render rationale), [GPU Rendering & Metal](../02-internals/03-gpu-rendering-metal.md).
