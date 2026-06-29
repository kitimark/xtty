## Why

P6a's git-review panel shows a plain unified diff: a changed line is tinted whole-line green/red, but the reader still has to scan the line to find *what* changed — weak exactly for the panel's signature use (reviewing what an agent just edited: a renamed identifier, one changed argument). The deferred "P6a+" intra-line emphasis is now decided (token-level word-diff; see `research/03-analysis/p6-file-diff-decisions.md` → "P6a+ addendum") and is a small, bounded, zero-dependency add that turns "this line changed" into "*these tokens* changed". This change also adds a tiny refresh-policy guard the P6a tracker over-claimed but never shipped.

## What Changes

- **Intra-line diff emphasis.** Within a *changed* line, emphasize only the changed token spans (a darker background over the existing whole-line tint), computed by a new view-free `XttyCore` module: tokenize each line, run a small token-level LCS/DP, emit changed-token ranges. **Gated and bounded** (replacement-run ≤5 line-pairs, ≤512 bytes/line, 1:1 positional pairing with equal deletion/addition counts, both sides non-empty, and a ratio gate that drops emphasis on near-total rewrites) so cost stays trivial and the panel degrades to today's whole-line styling whenever the gate fails. Rendered via `Text(AttributedString)` per-run background.
- **Pause the poll during the user's own git.** The ~5 s poll backstop SHALL skip a tick while the focused session's foreground command is a `git` invocation (the OSC-133 running-command signal). The `commandEnd` fast-path, focus, and manual refresh are unaffected. This removes a transient mid-operation file-list flash and reconciles an over-claimed P6a task (min-spacing was subsumed by the existing serialize; dedup-by-toplevel is moot for a single focused target; pause-during-own-git is now actually built).
- **Harness.** The `gitReview` DEBUG state-dump gains the selected diff's intra-line emphasis spans (counts/ranges only, never text); a new e2e asserts a substring edit produces emphasis.
- **Out of scope (kept deferred):** syntax highlighting, FSEvents auto-refresh, unbalanced-run (unequal del/add count) emphasis, next/prev-hunk keyboard nav, ahead/behind counts. No new config key, no new keybinding.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `git-review`: adds an **intra-line diff emphasis** requirement (within a changed line the read-only diff SHALL emphasize the changed token spans when a bounded gate is met, falling back to whole-line styling otherwise — view-free computation); modifies **Lean, gated refresh** so the periodic poll does no work while the focused session's foreground command is a git invocation.
- `verification-harness`: the `gitReview` state-dump snapshot additionally exposes the selected diff's intra-line emphasis spans (counts/ranges, never text); git-review e2e coverage gains an intra-line-emphasis scenario.

## Impact

- **`XttyCore`** (view-free, unit-tested): a new word-diff module (tokenizer + token-level DP + replacement-run detection + the gate), and an `emphasis` field on the existing `DiffLine` model in `GitDiff.swift`. No new dependency.
- **App layer:** `GitReviewView.swift` `DiffLineRow` renders per-run `.backgroundColor` (marker rendered separately, never tinted); `GitReviewController.swift`/`GitRunner.swift` compute emphasis off-main when loading a diff and add the poll-skip guard; the `gitReview` dump field gains emphasis spans.
- **Refresh policy:** the focused pane's running-command (OSC-133) is read at poll time to gate the poll.
- **Platform:** `Text(AttributedString)` per-run `.backgroundColor` is macOS 12+ (target 14–26) — no availability guard, no `NSViewRepresentable` fallback.
- **Read-only and lean preserved:** no write operations, no new deps, cost bounded by the gate + existing per-file/-line caps.
