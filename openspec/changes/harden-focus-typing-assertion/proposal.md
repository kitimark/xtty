## Why

The focus-on-activate XCUITest (`testFocusTypingOnActivateWithoutClicking`) is a **false negative** on GitHub-hosted CI: the runner's ~72-char hostname prompt soft-wraps the typed marker across two physical terminal rows, and because the DEBUG grid dump joins physical rows with `\n`, the contiguous `waitForContains(marker)` never matches — even though focus works and the marker is visibly on screen (proven by the banner-free post-merge run `28467944762`; research §12). The test guards a real product behavior — typed input reaches the focused pane on activate **without a click** — so we harden the assertion rather than weaken or delete the test.

## What Changes

- Add a **soft-wrap-robust** content matcher to the XCUITest grid-dump reader — a **scoped, opt-in** variant; the strict default matcher is unchanged for its other callers.
- Use it in `testFocusTypingOnActivateWithoutClicking` so a soft-wrapped marker is matched, while a **genuinely absent** marker still fails the assertion (the test keeps its real negative power).
- Document that the DEBUG grid dump emits **physical rows joined with `\n`** so the next type-at-prompt test knows the constraint.
- **Out of scope (deferred):** the six "Bucket-B" Cmd-key/menu-delivery failures (split/new-tab/paste/emoji/find/churn) — those need in-process drive-path plumbing and belong to a later `harden-xcuitests-for-ci`. This change is the wrap fix only.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `verification-harness`: add a requirement that the deterministic content assertion holds when typed content is **soft-wrapped** across physical grid rows.

## Impact

- **Test-only, no product code, no SwiftTerm patch, no new dependency.** Changes are confined to `AppUITests/`:
  - `AppUITests/XttyUITestSupport.swift` — `GridDumpReader` gains a wrap-tolerant matcher.
  - `AppUITests/XttyUITests.swift` — the focus test calls it.
  - `App/UITestDump.swift` — a one-line comment noting the dump is physical-rows-joined-with-`\n` (no behavior change).
- Rejected alternative (recorded in design): a producer-side "logical-line" dump using `BufferLine.isWrapped` — that field is **internal**, so it would cost a 3rd accessor on the gitignored SwiftTerm patch for DEBUG-only value; disproportionate.
- Greens 1 of the 7 CI `build-and-test` failures; the GUI job stays non-blocking and `test-core` stays the only required gate.
