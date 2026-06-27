## 1. Project generation (XcodeGen)

- [ ] 1.1 Add XcodeGen as a project prerequisite (install + pin/note version in AGENTS.md)
- [ ] 1.2 Write `project.yml`: app target (SwiftUI), `XttyCore` package, recent macOS deployment target, bundle id, app display name
- [ ] 1.3 Configure signing in `project.yml`: App Sandbox OFF, "Sign to Run Locally" (no Hardened Runtime/notarization yet)
- [ ] 1.4 Add `xtty.xcodeproj` to `.gitignore`; document the `xcodegen generate` step in AGENTS.md

## 2. XttyCore module (the seam)

- [ ] 2.1 Create the `XttyCore` Swift package (local SPM) with a placeholder type
- [ ] 2.2 Ensure `XttyCore` has no import of the app/UI target or a concrete terminal view
- [ ] 2.3 Add a smoke test target for `XttyCore` (one test that runs without launching the app)

## 3. App shell

- [ ] 3.1 Add SwiftTerm as a dependency of `XttyCore` (resolves + builds; not used in UI yet)
- [ ] 3.2 Implement a minimal SwiftUI `App` that opens a single empty window
- [ ] 3.3 App target depends on `XttyCore`

## 4. Verify

- [ ] 4.1 Generate the project (`xcodegen generate`) on a clean state; confirm `xtty.xcodeproj` is produced and gitignored
- [ ] 4.2 Build succeeds and the app launches to an empty window (no shell/render started)
- [ ] 4.3 `XttyCore` smoke test passes
- [ ] 4.4 Inspect built app entitlements: `com.apple.security.app-sandbox` absent/false
- [ ] 4.5 Run `openspec validate add-app-skeleton` and resolve any issues
