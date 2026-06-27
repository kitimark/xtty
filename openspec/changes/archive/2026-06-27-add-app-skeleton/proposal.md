## Why

xtty has a complete research and design plan but no code. Milestone P0 starts the build by standing up a native macOS app **and** drawing the architecture's load-bearing seam (engine-vs-view) before any feature code accretes — so the staged SwiftTerm adoption (start Level 3, drop to Level 1 only if measured) stays reversible.

## What Changes

- Add a native macOS **SwiftUI app** target that launches an empty window.
- Add a local Swift package **`XttyCore`** (near-empty) as the engine-facing seam: all future xtty logic talks to the terminal engine through `XttyCore`, never to view internals.
- Add **SwiftTerm** as a dependency (resolved and building; not yet wired into the UI).
- Manage the Xcode project with **XcodeGen**: commit a small `project.yml`; generate and gitignore `xtty.xcodeproj`.
- Configure signing with **App Sandbox OFF** and "Sign to Run Locally" (Hardened Runtime + notarization deferred to the later measure/polish milestone).
- **Out of scope (no behavior yet):** spawning a shell, rendering work, tabs/splits, OSC capture, sidebar/file-diff. The window stays empty.

## Capabilities

### New Capabilities
- `app-shell`: the buildable native macOS application shell — launches a window, defines the project/module structure (`XttyCore` seam), and sets the non-sandboxed signing posture.

### Modified Capabilities
<!-- none — this is the first change; no existing specs -->

## Impact

- **New project scaffold:** `project.yml` (XcodeGen), generated `xtty.xcodeproj` (gitignored), app target sources, `XttyCore` Swift package + smoke test.
- **Dependencies:** adds SwiftTerm (SPM).
- **Tooling:** introduces XcodeGen as a build prerequisite (documented in AGENTS.md).
- **Distribution posture:** App Sandbox disabled (rules out Mac App Store; aligns with the free/open, no-account values). No runtime behavior or user-facing terminal features yet.
- Follows `research/04-design/02-milestones.md` (P0) and the SwiftTerm adoption decision in `research/04-design/01-stack-sketch.md`.
