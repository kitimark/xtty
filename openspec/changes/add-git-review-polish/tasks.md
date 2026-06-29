## 1. XttyCore — intra-line emphasis algorithm + model

- [ ] 1.1 **Spike (do first):** prototype tokenize→token-DP on ~10 representative line-pairs (single edit, multi-edit-with-shared-interior, near-total rewrite, leading/trailing-only change, CJK, non-BMP emoji, combining marks); eyeball span quality and confirm grapheme offsets will map cleanly. Capture the chosen tokenizer rule + ratio threshold (design D1/D2).
- [ ] 1.2 Add `emphasis: [Range<Int>]` (default `[]`) to `DiffLine` in `XttyCore/Sources/XttyCore/GitDiff.swift`, plus a `DiffLine.content` computed property (text minus the single leading marker char) as the **one source of truth** for the marker-stripped content; document that `emphasis` indices are `Character`/grapheme offsets into `content` (never UTF-16/scalar). Keep `DiffParser` output unchanged (emphasis empty until refined).
- [ ] 1.3 Implement a view-free emphasis module (e.g. `WordDiff`/`DiffEmphasis`): a grapheme-aware tokenizer (word / punctuation / whitespace runs), common-prefix/suffix trim, a token-level LCS/Wagner–Fischer DP, and changed-token→`content`-range mapping (over `DiffLine.content`).
- [ ] 1.4 Implement replacement-run detection over a hunk's lines (consecutive deletions then additions; context/hunkHeader lines split runs) and the gate, **evaluated in order**: (1) del-count == add-count ≤ 5 line-pairs; (2) each line ≤ 512 bytes; (3) both sides non-empty; (4) after the per-pair DP, ratio ≤ ~60% per line (else drop that line). Failed gate → leave `emphasis` empty, no error, no unbounded work (design D2).
- [ ] 1.5 Add a pure `refine(FileDiff) -> FileDiff` entry point that annotates paired lines' `emphasis`; wire it into **all three** `DiffParser.parse` exits in `App/GitRunner.swift` `diff(...)` (untracked `--no-index`, `diff HEAD`, staged) — ideally one shared `return refine(parsed)` — so emphasis is applied regardless of file kind.
- [ ] 1.6 Unit tests (no app, no view): tokenizer; token-DP on the spike pairs incl. CJK/emoji/combining marks and a **two-separate-edits-with-unchanged-middle** case; replacement-run detection across interleaved context lines; **the line-pair cap boundary (5 pairs → emphasis, 6 → fallback)**; every gate branch (too many pairs, too-long line, unbalanced counts, ratio-exceeded, pure-add/pure-del) → empty emphasis; balanced single-line/multi-line edits → expected `content`-relative ranges.

## 2. App — render intra-line emphasis

- [ ] 2.1 In `App/GitReviewView.swift` `DiffLineRow`, render the leading `+`/`-`/space marker as a separate fixed-width `Text` (never tinted) and the content as `Text(AttributedString)`.
- [ ] 2.2 Render `DiffLine.content` (the shared helper) as the `Text(AttributedString)`; apply a darker `.backgroundColor` run over each `emphasis` range (content-relative, maps directly onto the content `Text` — no marker arithmetic); map offsets via `index(_:offsetByCharacters:)` over `content`; **clamp/ignore any out-of-range range (never trap)**; build the `AttributedString` once (not in a recomputed `body` path).
- [ ] 2.3 Confirm no availability guard / no `NSViewRepresentable` (macOS 12+ for `Text` `backgroundColor`); keep the existing `LazyVStack` + 2-axis `ScrollView`; pin a fixed monospaced row height.

## 3. App — pause the poll during the user's own git

- [ ] 3.1 Add a pure git-command predicate: trim leading whitespace, split on whitespace, first token **exactly** `== "git"`. Unit-test it: `git rebase -i`/`git  add` → true; `github-cli …`/`gitk`/`mygit` → false; `sudo git`/`/usr/bin/git`/`GIT_OPTIONAL_LOCKS=0 git`/`cd x && git` → false (accepted benign false-negatives — they over-refresh, never over-suppress); empty/absent → false.
- [ ] 3.2 Plumb the signal: add `runningCommand: String?` to `GitReviewTarget` and populate it from `session.runningCommand` in `currentGitReviewTarget()` (it is **not** read there today — the line-319 `runningCommand` is `SidebarPaneItem`). Add a trigger discriminator to `performRefresh` (`.poll | .commandEnd | .focus | .manual`); the poll timer passes `.poll`, existing call sites pass their kind.
- [ ] 3.3 In `performRefresh`, evaluate the poll-skip guard **first** — before the visibility/target gates and before the `if inFlight { pending = true }` coalescing — returning without setting `pending`, so a suppressed poll isn't resurrected by the bare `performRefresh()` pending-drain. Suppress **only** when trigger is `.poll` AND `runningCommand` is a git invocation; `.commandEnd`/`.focus`/`.manual` always proceed (best-effort: no running command → proceed).
- [ ] 3.4 Verify the gating decision (poll-absence isn't deterministically dump-observable, so test the decision directly): a unit/seam test that `performRefresh(.poll)` with `runningCommand == "git …"` performs no git query, while `.poll` with a non-git command and `.commandEnd`/`.focus`/`.manual` proceed.

## 4. Harness — dump field + e2e

- [ ] 4.1 Extend the `gitReview` DEBUG state-dump `selectedDiff` with the intra-line emphasis spans (counts/ranges only, never text). This requires the dump to **iterate `selectedDiff` hunks→lines** for emphasis (`gitReviewDump` does not walk lines today), reading the cached snapshot (no git exec in the dump path). Mirror `select()`'s `selectedPath == path` staleness guard on the refresh-path selection merge so the new field can't ride a stale clobber.
- [ ] 4.2 Add an XCUITest scenario: drive the injected zsh to make a partial single-line change in a tracked file, select it, and assert the dump's `selectedDiff` reports non-empty emphasis spans; degrade to screenshot when capture/hook is absent (Release).

## 5. Validation + docs

- [ ] 5.1 `swift test --package-path XttyCore` green; `xcodebuild test -scheme xtty -destination 'platform=macOS' -only-testing:xttyUITests/<git-review suite>` green.
- [ ] 5.2 `openspec validate add-git-review-polish` clean.
- [ ] 5.3 Update `config.example` only if anything user-facing changed (expected: nothing — no new key); update the trackers (AGENTS Current status, milestone P6a+ state) on completion per the repo convention.
