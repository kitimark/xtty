## Context

P6a (`add-git-review`, archived) ships a read-only git-review panel whose unified diff tints whole changed lines green/red (`App/GitReviewView.swift` `DiffLineRow`, a plain `Text(line.text)` + whole-row `.background()`), over a view-free model (`XttyCore/.../GitDiff.swift`: `DiffLine`/`DiffHunk`/`FileDiff`). Diffs are loaded lazily per file off-main in `App/GitReviewController.swift`/`GitRunner.swift`, capped at `maxLines: 5000` / `maxLineLength: 3000`. Refresh is `commandEnd` fast-path + a 5 s poll + focus + manual, debounced + serialized, visible/local-gated — but with **no** running-command gate today.

This change implements the decided "P6a+ addendum" (`research/03-analysis/p6-file-diff-decisions.md`): **token-level intra-line emphasis** plus a one-line **pause-during-own-git** poll guard. The addendum is source-grounded (delta/zed/diff-match-patch hand-reads + a multi-agent workflow with adversarial verification); this doc records the resulting technical choices.

## Goals / Non-Goals

**Goals:**
- Emphasize the changed token spans *within* a changed line, distinct from the whole-line tint, so reviewing an agent's edit shows *what* changed.
- Keep it LEAN: pure-`XttyCore` algorithm, zero new dependencies, cost bounded by a gate + the existing caps, computed off-main.
- Suppress the periodic poll while the user runs their own git, removing a transient flash and reconciling the over-claimed P6a `tasks.md` 5.3.

**Non-Goals:**
- Syntax highlighting (dep cost; against LEAN).
- FSEvents auto-refresh (dogfood-gated).
- Unbalanced-run (unequal del/add count) emphasis — the named upgrade.
- next/prev-hunk keyboard nav, ahead/behind counts (would add keybinding/header surface for modest value).
- Any write operation, new config key, or new keybinding.

## Decisions

### D1 — Algorithm: token-level LCS/DP on the changed line-pair (not trim-only, not char-level)

Tokenize each line into word / punctuation / whitespace runs, then run a small LCS / Wagner–Fischer DP **over the tokens** and emit the byte (grapheme) ranges of the changed tokens on each side. A common-prefix/suffix grapheme trim runs first as a cheap fast path.

- **Why not trim-only:** every reference (diff-match-patch `diff_main`) uses prefix/suffix trim as a *speedup preamble*, then a real diff on the residue; trim-only over-highlights any multi-edit line (`foo(a,b,c)` → `foo(x,b,y)` lights up the whole `,b,` interior) — exactly the agent-review case.
- **Why not char-level:** char-level needs a separate word-boundary "snap" pass to avoid ragged sub-token spans (the synthesis's #1 risk). Token-level is word-aligned *by construction* — tokenizing **is** the boundary handling — so it drops the snap pass entirely. delta (`\w+` tokens) and zed (`CharClassifier` tokens) — the two code-focused tools — both tokenize; diff-match-patch is char-level because it diffs arbitrary prose.
- **Why DP is cheap here:** the cost lever is tokenization, not trimming — DP over the *typical* ~tens of tokens is ~hundreds of cells (char-level over the 3000-char cap would be ~9M). The true worst case is bounded by the 512-byte line cap (D2): a line of all-distinct single-char tokens is ≤512 tokens → ≤~262k cells per pair × ≤5 pairs — still trivial, and run off-main. Because bytes ≥ graphemes, the byte cap is a safe grapheme bound and auto-excludes any 3000-char-truncated line.
- **Upgrade trigger (deferred):** if sub-token precision is ever wanted, swap the token unit for graphemes — same DP. If unbalanced runs matter, see D2's note.

### D2 — Gate: a bounded, balanced replacement run

Operate on a **replacement run** = a maximal block of consecutive `.deletion` lines immediately followed by consecutive `.addition` lines *within one hunk* (context/`hunkHeader` lines split runs — the detector must handle interleaving; it is the part most likely to mis-pair, so it is unit-tested directly). Emphasis is computed only when, **evaluated in this order** (cheap structural gates first, so a failing run never reaches tokenize/DP):

1. deletion-count **==** addition-count, and that count is **≤ 5 line-pairs** (the cap is per-side line count, which equals pairs since the counts are equal — zed `MAX_WORD_DIFF_LINE_COUNT`, balanced-path semantics) — the real cost bound + the pairing precondition;
2. each line is **≤ 512 bytes** (zed `MAX_WORD_DIFF_LEN`) — belt-and-suspenders against one pathological long line in an otherwise small run (the gap the adversarial pass flagged in zed's live-path gate);
3. both sides non-empty (skip pure-add / pure-del runs);
4. *(after the per-pair token DP runs)* the emphasized fraction is **≤ ~60 %** (a *ratio gate*, `similar`'s `min_ratio` idea) — above it the line is a rewrite, not an edit, so drop that line to whole-line styling.

Pairing is **1:1 positional** (`del[i] ↔ add[i]`), each pair diffed independently → line-local ranges (the simplest mechanism to test). Any failed gate → no emphasis for that run/line, plain whole-line styling, no error, no unbounded work. The equal-count requirement is a *pairing-mechanism precondition*, not a cost gate; the **named upgrade** for unbalanced runs (e.g. 2→3) is to diff the run's *concatenated* deletion-text vs addition-text in one pass (zed's standalone-path shape) — deferred.

### D3 — Model: an `emphasis` field on `DiffLine`, computed off-main as a separable pass

Add `emphasis: [Range<Int>]` (default `[]`) to `DiffLine` in `GitDiff.swift`. **Offset contract (one source of truth):** offsets are **extended-grapheme-cluster (`Character`) offsets into the marker-stripped content** — i.e. `DiffLine.text` with its single leading marker character (`+`/`-`/space) dropped. Add a `DiffLine.content` computed property (text minus the leading marker) in `XttyCore` and make **every consumer use it** — the emphasis computation, the renderer, and the DEBUG dump — so the strip rule cannot drift across modules. `[Range<Int>]` indices are `Character` offsets into `content`, never UTF-16/scalar offsets.

A new view-free module (e.g. `WordDiff`/`DiffEmphasis`) exposes a pure `refine(FileDiff) -> FileDiff` that walks hunks, detects replacement runs (D2), applies the gate, and annotates the paired lines' `emphasis` (over `content`). `DiffParser` stays unchanged. **`GitRunner.diff(...)` has three `DiffParser.parse` exits** (untracked `--no-index`, `diff HEAD`, staged) — `refine` MUST wrap **all** of them (cleanest: one `let parsed = …parse(…); return refine(parsed)` per branch, or refactor to a single return) so emphasis is applied consistently regardless of file kind. This runs off-main (already), so the App renders pre-computed spans. Pure + unit-testable, matching `OSC133`/`LinkOpen` precedent.

### D4 — Rendering: `Text(AttributedString)` per-run background, marker rendered separately

`DiffLineRow` renders the marker (`+`/`-`/space) as a **separate fixed-width leading `Text`** (never tinted, never emphasized — also fixes column alignment in the narrow panel) and the **`DiffLine.content`** (D3's shared helper) as a `Text(AttributedString)` whose `emphasis` ranges get a **darker** `.backgroundColor` over the existing whole-line `.opacity(0.18)` tint (zed's two-layer model). Because the content is rendered as its own `Text`, the content-relative `emphasis` offsets map directly onto it — no marker arithmetic. `backgroundColor` is honored by SwiftUI `Text` since **macOS 12** (target 14–26) — no availability guard, no `NSViewRepresentable` fallback. The styled `AttributedString` is built once in the model/row, not in a recomputed `body` path. Map each `Range<Int>` to `AttributedString.Index` via `index(_:offsetByCharacters:)` over `content` (same `Character` unit end-to-end — xtty already round-trips CJK + non-BMP emoji), and **clamp/ignore any out-of-range range** (defensive: a future parser/strip drift must degrade to no-emphasis, never trap). Keep the existing `LazyVStack` in the 2-axis `ScrollView`; pin a fixed monospaced row height.

### D5 — Pause-during-own-git: suppress only the poll tick

The OSC-133 running command **is** available view-free on `TerminalSession.runningCommand`, but it is **not** yet plumbed into the git-review path: `GitReviewTarget` has no such field, and `performRefresh()` takes no trigger argument (the `runningCommand` at `TerminalWindowController.swift:319` belongs to `SidebarPaneItem`, a different struct). Three changes make the guard correct:

1. **Plumb the signal:** add `runningCommand: String?` to `GitReviewTarget` and populate it from `session.runningCommand` in `currentGitReviewTarget()`.
2. **Discriminate the trigger:** give `performRefresh` a trigger argument (`.poll | .commandEnd | .focus | .manual`); the poll timer passes `.poll`, the existing call sites pass their kind. The guard consults the git predicate **only** for `.poll` — so a manual/focus/commandEnd refresh *issued while a git command runs* still queries (the spec's "SHALL NOT be suppressed").
3. **Evaluate the guard EARLY:** place the poll-skip check at the **top** of `performRefresh`, *before* the visibility/target gates and *before* the `if inFlight { pending = true }` coalescing, and return without setting `pending`. Otherwise a suppressed poll could be resurrected by the bare `performRefresh()` pending-drain (which carries no trigger).

**Predicate (the unit-testable surface, mechanism-neutral in the spec):** trim leading whitespace, split on whitespace, and match the first token **exactly** `== "git"`. This deliberately accepts benign **false-negatives** — `sudo git`, `/usr/bin/git`, `GIT_OPTIONAL_LOCKS=0 git`, `cd x && git …` are *not* recognized and will still poll — because the failure mode is only an extra read (over-refresh), never a wrong suppression. It must **not** match git-prefixed *other* programs (`github-cli`, `gitk`). The guard is **best-effort**: when OSC-133 reports no running command (cmdline absent), it does nothing and the poll proceeds as today.

Drop lazygit's `pauseRefreshesCount` mechanism wholesale: its rationale is bracketing lazygit's *own* multi-step git ops, not lock contention (xtty's poller is read-only with `GIT_OPTIONAL_LOCKS=0`), so it does not transfer.

### D6 — `tasks.md` 5.3 reconciliation

P6a `tasks.md` 5.3 claimed min-spacing + dedup-by-toplevel + pause-during-own-git shipped; the code has none. This change builds pause-during-own-git (D5). The other two are not built and not needed: min-spacing is subsumed by the existing serialize (in-flight + pending), and dedup-by-toplevel is moot — the controller only ever refreshes the single *focused* target. Recorded here so the spec/tracker reflect reality; the archived `tasks.md` is left as historical record.

### D7 — Spec shape: emphasis as ADDED, not MODIFIED

The addendum's spec-surface line phrased emphasis as *modifying* the existing read-only-diff requirement; the delta instead introduces a **new ADDED requirement** ("Intra-line diff emphasis"). This is an intentional divergence — it avoids re-pasting the panel requirement's whole block, and the new requirement can explicitly preserve the read-only / classified-line guarantees. Semantically equivalent; noted for traceability.

## Risks / Trade-offs

- **Ragged or wrong emphasis on tricky pairs** → token granularity avoids sub-token raggedness by construction; the ratio gate drops rewrites; a pre-commit spike (Open Questions) eyeballs ~10 representative pairs (single edit, multi-edit-shared-interior, rewrite, CJK, non-BMP emoji, combining marks).
- **Grapheme/offset unit mismatch corrupts runs on emoji/CJK** → compute and render in the same `Character`/grapheme unit; map via `index(_:offsetByCharacters:)`; covered by a CJK/emoji unit test.
- **Marker tinted or column misaligned (off-by-one)** → marker is a structurally separate, never-styled leading `Text`; emphasis offsets are content-relative; covered by the spike + a parser unit test.
- **Replacement-run detector mis-pairs across interleaved context lines** → detector is pure and unit-tested directly (the part most likely to be wrong).
- **AttributedString construction per row** is the real cost, not the CoreText pass → build once in the model; the existing 5000-line cap + lazy-per-file load bound it.
- **pause-during-own-git hides a genuine update** → only the *poll* is suppressed; `commandEnd` refreshes the instant the git command finishes, so the window is cosmetic.

## Open Questions

- ❓ **Pre-commit spike (~1–2 h):** run tokenize→DP on ~10 representative pairs and confirm both emphasis quality *and* grapheme-aligned rendering through a real `Text(AttributedString)`. Validates D1+D4 together before broad implementation.
- ❓ Ratio-gate threshold (~60 %) and run line-cap (5) are borrowed from zed/`similar`; confirm they feel right during dogfooding (cheap to tune, no API change).
