## Why

The git-review panel is a fixed-width (~280 pt) column, but the selected file's unified diff renders far narrower than the panel — long lines wrap at roughly 40% of the available width, leaving most of the column empty and the diff hard to read. The intended behavior (P6 design: *horizontal scroll for long lines*) never materialized; the two-axis `ScrollView` + `LazyVStack` + `frame(maxWidth: .infinity)` combination collapses the content width instead. Since the panel is narrow and often reviews prose/markdown, "fill the width" splits into two legitimate behaviors (wrap vs. horizontal scroll), so the fix both corrects the width and lets the user choose.

## What Changes

- The read-only unified diff SHALL fill the **full panel width** in both a **wrap** and a **no-wrap** mode:
  - **wrap** (new default): long lines fold onto continuation rows that hang-indent under the content column (the leading `+`/`-`/space marker stays in its own gutter); no horizontal scrolling.
  - **no-wrap**: each diff line stays on one row and the panel scrolls **horizontally**, with the line tint spanning the full scroll width so columns stay aligned (the behavior the P6 design called for on long lines).
- An in-panel **wrap toggle** SHALL be added to the diff header (next to open-in-editor), mirroring the existing flat↔tree layout control — button only, no keybinding.
- A new base-profile config key **`git-review-diff-wrap`** (`wrap` | `nowrap`, default `wrap`) SHALL set the panel's default diff wrap mode, with invalid values falling back to the default and logged — exactly how `git-review-layout` behaves.
- The DEBUG state dump's git-review snapshot SHALL expose the active **`diffWrap`** mode plus DEBUG **diff layout-geometry** signals (whether the selected diff fills the panel width and whether it overflows the panel horizontally) so the toggle, the configured default, **and the actual rendered layout of each mode** are deterministically assertable by XCUITest.
- Presentation only: the diff parser, hunk/line model, intra-line emphasis, and the panel's read-only nature are **unchanged**.

## Capabilities

### New Capabilities

<!-- none -->

### Modified Capabilities

- `git-review`: adds a **Diff line-wrap mode** requirement — the read-only diff fills the panel in a configurable, in-panel-toggleable wrap/no-wrap mode (presentation only, layout-agnostic, read-only preserved).
- `terminal-configuration`: the **Configuration schema with defaults and per-key fallback** requirement gains the base-profile `git-review-diff-wrap` key (`wrap` default, invalid → default + logged).
- `verification-harness`: the **Deterministic content assertion channel** git-review snapshot gains a `diffWrap` field and DEBUG diff layout-geometry signals (fills-width / horizontal-overflow), and **Git-review end-to-end coverage** gains scenarios asserting the mode flips when the **real in-panel control** is driven and that each mode produces the expected geometry.

## Impact

- **`XttyCore`**: new `GitDiffWrap` enum + `diffWrap` state and a `setDiffWrap` mutator on `GitReviewStore` (mirrors `GitReviewLayout`/`setLayout`); `git-review-diff-wrap` parsing in `XttyConfigLoader`; a `gitDiffWrap` field on **`XttyConfigSet`** (a global base-only field beside `confirmClose`/`gitReviewLayout`, **not** a per-profile field; the loader warns and ignores the key inside profile blocks). Unit-testable, no view types.
- **App**: `App/GitReviewView.swift` — a wrap toggle button in the `DiffPane` header, a mode branch in `DiffLineRow`/`DiffPane` (the only visible layout change), and a DEBUG-only `GeometryReader` feeding the selected diff's fills-width/overflow signals into the store; `App/TerminalWindowController.swift` — thread `configSet.gitDiffWrap` into the store and add `diffWrap` + the geometry signals to `gitReviewDump`; `App/XttyApp.swift` — read `configSet.gitDiffWrap` at every controller-creation site.
- **Tests**: `XttyCore` config-loader unit tests for the new key + a `GitReviewStore` unit test that `setDiffWrap` flips the value and bumps `revision`; an XCUITest that drives the **real** `gitReview.wrapToggle`, asserting via the state dump that `diffWrap` flips, reflects the configured default, and that each mode produces the expected fills-width / horizontal-overflow geometry.
- No change to the diff parser, git query/refresh path, or the read-only scope. No new keybinding, no menu change.
