## Context

xtty is greenfield with a complete plan in `research/` but no code. This change implements milestone **P0** ([research/04-design/02-milestones.md](../../../research/04-design/02-milestones.md)). The key constraints come from the stack sketch and its adoption decision ([research/04-design/01-stack-sketch.md](../../../research/04-design/01-stack-sketch.md)): All-Swift, macOS-first, lean/latency-first, and **staged SwiftTerm adoption — start at Level 3, drop to Level 1 only if measured**. P0's job is to make that staging *possible* by drawing the engine-vs-view seam up front.

## Goals / Non-Goals

**Goals:**
- A buildable native macOS app that launches an empty window.
- An `XttyCore` module establishing the engine-facing seam (so the render layer stays swappable).
- SwiftTerm available as a resolved dependency.
- Reproducible, clean-git project generation (XcodeGen).
- Non-sandboxed signing posture set correctly from the start.

**Non-Goals:**
- Any terminal behavior (shell spawn = P1), rendering, tabs/splits, OSC capture, sidebar, or file/diff.
- Hardened Runtime / notarization (deferred to the measure/polish milestone).
- Wiring SwiftTerm into the UI (P1).

## Decisions

- **Start at SwiftTerm Level 3, behind the `XttyCore` seam.** The three adoption levels share one engine, always reachable via `TerminalView.getTerminal()`, so the choice is reversible. We start at L3 (most reuse) but require all xtty logic to talk to the engine through `XttyCore`, never to view internals — making a future L3→L1 swap a contained render-layer refactor. *Alternative considered:* build our own renderer now (L1) — rejected as premature; control should be bought with measurement, not speculation.
- **App Sandbox OFF.** A sandboxed terminal cannot usefully spawn shells or read the user's files (children inherit the sandbox). Sandbox and Hardened Runtime are independent; only Hardened Runtime is needed for notarization, and that is deferred. *Alternative:* sandboxed + temporary-exception entitlements — rejected as crippling and Mac-App-Store-oriented, which conflicts with the free/open/no-account values.
- **XcodeGen for the project.** Commit a small `project.yml`; generate and gitignore `xtty.xcodeproj`. Keeps git clean and the project reproducible. *Alternatives:* committed `.xcodeproj` (noisy/merge-prone) or SPM-only (awkward `.app` bundle/entitlements/signing). Chosen for clean git + reproducibility, accepting one extra build tool.
- **Module layout:** thin SwiftUI app target depends on a local `XttyCore` SPM package; `XttyCore` depends on SwiftTerm. Logic lives in `XttyCore` (fast to build, unit-testable without launching the app).

## Risks / Trade-offs

- **Extra tooling (XcodeGen) is a prerequisite.** → Document the generate step in AGENTS.md; pin/verify the tool version.
- **Non-sandboxed rules out the Mac App Store.** → Accepted; aligns with distribution values. Developer ID + notarization handled later.
- **Seam discipline can erode** if later code reaches into the view directly. → Encode the rule in the `app-shell` spec and AGENTS.md; keep `XttyCore` free of UI imports.
- **SwiftTerm's default render/footprint may not meet M1/M4.** → Out of scope here; this is exactly what the later measure milestone gates, with the L1 escape hatch ready *because* of this seam.

## Open Questions

- Exact deployment target (a recent macOS for modern Metal/SwiftUI) — finalize when writing `project.yml`.
- Bundle identifier / app display name — pick at implementation time.
