## Why

Scrolling a full-screen mouse-tracking program (htop, or any ncurses program that uses hardware scroll-region shifting) toward the top of its own list via xtty's mouse-wheel path corrupts the display — stale characters from long-past scroll positions bleed into the current view, and a moved row can appear duplicated at two physical positions. A same-session forensics investigation (`research/03-analysis/scroll-reversal-redraw-corruption-forensics.md`, §7) traced this to a real, source-confirmed defect in vendored SwiftTerm v1.13.0: the scroll-down (`SD`, `CSI Ps T`) handler is missing a guard its sibling scroll-up (`SU`, `CSI Ps S`) handler already has, so it always shifts only a single column instead of the full scroll region whenever column-margin-mode is inactive — which is virtually always, since almost no real program enables it. This breaks a common daily-driver workflow (scrolling any list-based full-screen program) and was only reachable after xtty's own `fix-scroll-wheel-mouse-reporting` shipped real wheel delivery to such programs; it does not block that change or `smooth-scroll-wheel-momentum`, both of which left it tracked separately.

## What Changes

- Patch vendored SwiftTerm's `cmdScrollDown` (`Terminal.swift`) to mirror `cmdScrollUp`'s existing `if marginMode { <narrow margin-bounded copy> } else { <full-width whole-line splice> }` shape. Today `cmdScrollDown` unconditionally takes the narrow, margin-bounded path — correct only when column-margin-mode (DECLRMM) is active and `marginLeft`/`marginRight` have been explicitly set — and silently drops every column past the first when they haven't (their unset default), which is the case for the alternate screen full-screen programs run on.
- Add a fast, deterministic, headless regression test (no PTY, no app, no real program) that constructs a `Terminal` directly, feeds a minimal synthetic escape sequence exercising `DECSTBM` + `SU` + `SD` over known multi-column content, and asserts the scroll-down shift moves every column in the region — not just the first.
- Extend end-to-end coverage with a real full-screen mouse-tracking program scrolled deep and then back toward the top via a real wheel gesture, asserting via the existing grid-dump content-assertion channel that no row shows corrupted or duplicated content after the reversal.
- Upstream PR preparation is deferred to a maintainer action, per this repo's established precedent for vendored-SwiftTerm fixes (`fix-scroll-wheel-mouse-reporting`, `smooth-scroll-wheel-momentum`).

## Capabilities

### New Capabilities

<!-- none — this fixes a defect in existing behavior -->

### Modified Capabilities

- `terminal-session`: the **Interactive terminal input and output** requirement's redraw-correctness guarantee — currently scoped to resize ("a full-screen program redraws correctly at the new size") — extends to cover wheel-driven scrolling of a full-screen program, including direction reversal, without corrupting its display.
- `verification-harness`: a new requirement adds fast headless-engine coverage plus real-program end-to-end coverage for scroll-region redraw correctness. (Deliberately does **not** touch the existing "Mouse-wheel routing is observable" / "Mouse-wheel routing end-to-end coverage" requirements, which `smooth-scroll-wheel-momentum` has pending edits against — avoids a same-requirement collision between two concurrently open changes.)

## Impact

- **SwiftTerm patch** (`patches/swiftterm/xtty-accessors.diff`): gains a new hunk touching `Terminal.swift`'s `cmdScrollDown` — a meaningful scope change from the patch's current purely-additive character (new accessor methods only, confined to `MacTerminalView.swift`) to also carrying a correctness fix in the vendored VT engine itself. Same reconstitute-from-pin discipline (`scripts/bootstrap-swiftterm.sh`); upstream PR remains a deferred maintainer action.
- **Tests**: a new headless `XttyCoreTests` regression (the `NoopTerminalDelegate` + `Terminal(delegate:)` pattern already used in `TerminalSessionTests.swift`) plus a new `AppUITests` end-to-end scenario driving a real full-screen program through a wheel scroll-then-reversal.
- **No** `terminal-configuration` / `terminal-keybindings` / mouse-wheel-routing impact — the routing decision (which branch a wheel gesture takes) is unchanged and already correct; this fixes what happens to the display *after* a program legitimately receives and acts on a wheel-routed scroll.
