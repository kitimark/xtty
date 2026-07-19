## 1. Core state + config (XttyCore)

- [x] 1.1 Add a `GitDiffWrap` enum (`.wrap` / `.noWrap`; `String`-backed, `Equatable`, `Sendable`, `CaseIterable`) in `GitReviewStore.swift`, alongside `GitReviewLayout`.
- [x] 1.2 Add `private(set) var diffWrap: GitDiffWrap = .wrap` and a `setDiffWrap(_:)` mutator to `GitReviewStore` that bumps the observable `revision` (mirror `layout` / `setLayout`).
- [x] 1.3 Parse the base-profile `git-review-diff-wrap` key (`wrap` | `nowrap`) in `XttyConfigLoader.swift` next to `git-review-layout`: valid → the mode, absent/invalid → `.wrap` with a logged warning.
- [x] 1.4 Resolve the default onto **`XttyConfigSet.gitDiffWrap`** (default `.wrap`; a global base-only field beside `confirmClose`/`gitReviewLayout`, **not** a per-`XttyProfile` field), and **warn + ignore** `git-review-diff-wrap` when it appears inside a profile block (mirror the loader's `git-review-layout` handling).
- [x] 1.5 Verify (`make test-core`): config-loader unit tests assert `git-review-diff-wrap = nowrap` → `.noWrap`, an invalid value → `.wrap` + logged, absence → `.wrap`, and that the key inside a profile block is ignored + logged.
- [x] 1.6 Verify (`make test-core`): a `GitReviewStore` unit test asserts `setDiffWrap` flips `diffWrap` **and bumps `revision`** (the re-render signal).

## 2. View: wrap toggle + two-mode layout (App/GitReviewView.swift)

- [x] 2.1 Thread the active `GitDiffWrap` from the store snapshot into `DiffPane` (value + an `onToggleWrap` closure, keeping `DiffPane` store-free like `onOpen`), and into `DiffLineRow`.
- [x] 2.2 Add a wrap-toggle button to the `DiffPane` header (next to open-in-editor): plain button, wrap/no-wrap SF Symbols, `accessibilityIdentifier("gitReview.wrapToggle")`, help text.
- [x] 2.3 Implement **wrap** mode: vertical-only content scroll; the `HStack { marker; content }` keeps the marker in its gutter while the content `Text` wraps (continuation lines hang-indent under the content); rows fill the panel width via `.frame(maxWidth: .infinity)` + `.fixedSize(horizontal: false, vertical: true)`.
- [x] 2.4 Implement **no-wrap** mode: keep the two-axis scroll but size rows to their single-line content width so the diff scrolls horizontally and each line's tint spans the full content width (fixes the current degenerate collapse — do **not** leave `maxWidth: .infinity` fighting a non-wrapping `Text`; per design R1, an eager `VStack` bounded by the 5000-line cap is the acceptable fallback for no-wrap only).
- [x] 2.5 Confirm intra-line emphasis, classified-line content, and the read-only scope are unchanged in both modes (presentation-only).
- [x] 2.6 Add a **DEBUG-only** `GeometryReader`/`onGeometryChange` around the diff content that derives whether the selected diff **fills the panel width** and whether it **overflows horizontally**, feeding those booleans into the store via an **equality-gated** observation channel that does **not** drive the render (design R5).

## 3. Config seam + harness observability (App)

- [x] 3.1 Thread **`configSet.gitDiffWrap`** through `XttyApp` (every controller-creation call site, read from the resolved set — not a profile) into `TerminalWindowController.init`, applying it via `store.setDiffWrap(...)` at setup (mirror `configSet.gitReviewLayout` / `setLayout`).
- [x] 3.2 Add to `gitReviewDump` in `TerminalWindowController.swift`: the `diffWrap` field (the store's active `GitDiffWrap.rawValue`) **and** the DEBUG diff layout-geometry signals (fills-width / horizontal-overflow booleans) from the store's observation channel. (No DEBUG toggle hook — the XCUITest drives the real `gitReview.wrapToggle` button.)

## 4. Verify

- [x] 4.1 By-effect visual check (`make run`): the diff fills the full panel width; in wrap a long line folds with a hanging indent; in no-wrap a long line stays whole and scrolls horizontally with its tint spanning the content width; an emphasized span straddling a wrap point still highlights.
- [x] 4.2 Add an XCUITest that **drives the real `gitReview.wrapToggle` button** (not a debug hook): launch with `git-review-diff-wrap = nowrap`, assert the dump's `diffWrap` reads `nowrap`, tap the toggle, assert it reads `wrap`; and for a diff with a line longer than the panel, assert the layout-geometry signals — wrap → fills-width && !overflows, no-wrap → overflows (assert the state-dump routing **and** geometry, not pixels — design D5).
- [x] 4.3 Run the Tier-1 XCUITest suite and confirm the new coverage is green with no regressions. ⟶ xtty-test-validator (Tier-1 `make test`)
- [x] 4.4 Update `packer/README.md` Acceptance envelope counts if the XttyCore and/or XCUITest totals moved (reverse duty for a test change).

## 5. Land the change

- [x] 5.1 Pre-archive coherence review of the change against AGENTS.md's rulebook and live disk state. ⟶ xtty-openspec-critic (add-git-diff-wrap-toggle) — verdict COHERENT; 3 findings (missing cross-review gate task — addressed by adding 5.2 below; AGENTS.md tracker drift owed to the archive-ritual step; implementation was uncommitted at review time — fixed in `e18e43d`)
- [ ] 5.2 Human-attestation cross-review (this change touches `App/*.swift` and `XttyCore/*.swift`, paths outside the docs/tracker allowlist, so it is mechanically **in scope** per `scripts/cross-review-scope.sh`). Run `/xtty:cross-review add-git-diff-wrap-toggle`, read the complete ledger. Then, on a clean tree, from the repo root, run:
  `scripts/cross-review-digest.sh --line add-git-diff-wrap-toggle | pbcopy`
  Record the reviewed-state digest on a delimited attestation line. **Source the pasted line only from a command YOU ran yourself in your own terminal — a line visible in a model's transcript, or already sitting on a clipboard a model populated, is not attestable provenance.** **HUMAN-ONLY — the model MUST NOT tick this task or derive the attested value:**
  `<!-- cross-review-attestation: base=<B> head=<HEAD> digest=<sha256> reviewed=<date> -->`
- [ ] 5.3 Archive + reconcile: merge the spec deltas (`openspec archive`), finish the merge by hand, tick trackers (Current-status row + snapshot + HISTORY narrative + milestone), and verify-against-disk. ⟶ archive-ritual
