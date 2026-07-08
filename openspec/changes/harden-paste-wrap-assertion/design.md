## Context

`testMultiLinePasteIsNotAutoExecuted` (`AppUITests/XttyUITests.swift:62–93`) puts a two-line payload (`alpha<tag>\nbeta<tag>`) on the pasteboard, presses **Cmd+V without Return**, then asserts (a) `:82` the first line reached the grid, (b) `:84` the second line reached the grid, and (c) `:87` the grid does **not** contain "command not found" (paste staged, not executed). Assertions (a) and (b) call `GridDumpReader.waitForContains(line, timeout: 5)` with the **strict** (default) matcher.

This is the *third* type-at-prompt-then-assert site to hit the soft-wrap hazard that `harden-focus-typing-assertion` (`:53`) and `harden-findbar-wrap-assertion` (`:198`) already fixed. Root cause, measured on the graphics zsh rig 2026-07-08 (run `2026-07-08-zsh-paste-forensic-graphics`, `paste-grid.txt`): the `add-vm-prompt-width-parity` 59-char hostname makes the zsh prompt exactly **70 columns**; `alpha<tag>` is always **9 chars** (`alpha` + a 4-digit tag), so `70 + 9 = 79 > 78`-column terminal and the token soft-wraps — the dump joins physical rows with `\n` (`App/UITestDump.swift`), yielding `alpha216`⏎`8`, which strict `contains("alpha2168")` can never satisfy. The paste **did** land and was **staged, not executed** (the screenshot shows zsh's highlighted bracketed-paste region; `:87` found no "command not found"). The second line `beta<tag>` is contiguous on its own row, so `:84` strict passes — which is why the failure is `:82` and never reaches `:84`. Fully deterministic (the token is always 9 chars → always wraps, irrespective of the random tag) — **not** the per-launch race class.

The wrap-tolerant matcher already exists — `GridDumpReader.waitForContains(_:timeout:ignoringLineWraps:)` (`XttyUITestSupport.swift:153`) — and so does its deterministic regression guard `testSoftWrapGuardIsWrapTolerant` (shipped by `harden-findbar-wrap-assertion`). This change consumes both; it introduces neither.

## Goals / Non-Goals

**Goals:**
- Make the multi-line-paste content assertions robust to terminal soft-wrap, so they pass when the paste lands and the terminal wraps a line, and fail only when a line never arrives.
- Green the wide-prompt **zsh** VM rig at `:82` (`40/1/1` → `41/0/1`) without a skip — the product is correct there, so the honest outcome is a real pass, not an `XCTSkip`.
- Keep the change **test-only** — no product code, no SwiftTerm patch, no new launch hook, **no new guard test**.

**Non-Goals:**
- The bash `:87` execution arm (`bash32-no-bracketed-paste`) — a shell-capability difference (bash 3.2 has no bracketed paste), owned by `split-shell-dependent-testplan` via `XCTSkipUnless`. Untouched here.
- Making the `:87` negative check wrap-tolerant (see D3).
- A producer-side "logical line" grid dump (see D5).
- Any new shell, GitHub-Actions zsh job, or product behavior change.

## Decisions

### D1: Apply the existing wrap-tolerant matcher at `:82` and `:84` — reuse, don't reinvent

Change both positive assertions to `GridDumpReader.waitForContains(line, timeout: 5, ignoringLineWraps: true)`, exactly mirroring `:53` and `:198`. No new matcher, no app code. Each line is a unique random single-word token (`alpha<tag>` / `beta<tag>`), so normalizing wrap boundaries cannot fabricate a match — a line that genuinely never landed stays absent from the grid → the assertion still fails. The strict default is unchanged for its ~15 other callers.

### D2: No new regression guard — the existing forced-wrap guard already covers this matcher

`harden-findbar-wrap-assertion` added `testSoftWrapGuardIsWrapTolerant`, which types a marker guaranteed to be wider than the pane and self-validates that (a) it genuinely spanned ≥2 physical rows (strict whole-token match is *false*) and (b) the wrap-tolerant match is *true*. That guard proves the matcher property **file-wide and deterministically in `make test`**, independent of prompt width and of which call site consumes the matcher. Adding a paste-specific guard would be redundant duplication for zero additional coverage. This is the key structural difference from the findbar change (which had to introduce the guard); here the guard is a dependency already in the tree.

### D3: Leave the `:87` negative "command not found" check strict — out of scope

`:87` is `XCTAssertFalse(grid.lowercased().contains("command not found"))`, a raw `String.contains` (not the `gridContains` helper), guarding "the paste was not executed." It is left strict because it is **not the failure path and cannot false-pass here**: on the zsh rig the paste is staged and never executes, so the phrase never appears; and were a paste ever executed, the shell error (`alpha<tag>: command not found`, ≤28 chars) begins at column 0 of a fresh row and does not reach the 78-column wrap boundary. Widening its tolerance would be scope creep with no failure to fix. (If a future change ever makes execution-error detection prompt-width-sensitive, that is its own harden task.)

### D4: Cross-change interaction with `split-shell-dependent-testplan` — the two paste arms are independent and compose

`testMultiLinePasteIsNotAutoExecuted` reds two different ways on two different rigs, and the fixes are orthogonal (different lines):

```
                 testMultiLinePasteIsNotAutoExecuted
                            │
        ┌───────────────────┴────────────────────┐
   bash rig :87                              zsh rig :82
   paste auto-executes                       paste lands, staged
   (bash 3.2 no bracketed paste)             but token soft-wraps
        │                                         │
   PREMISE FALSE → XCTSkipUnless             MATCHER BUG → ignoringLineWraps:true
   OWNED BY split-shell-dependent-testplan   OWNED BY this change (:82/:84)
```

After both land: on bash the test **skips** (`XCTSkipUnless(bracketedPasteMode)` — capability absent); on zsh it **runs and passes** (wrap-tolerant matcher — capability present, product correct). The edits do not collide — `XCTSkipUnless` sits at the top of the test body, the wrap-tolerance sits on the `:82`/`:84` assertions. This change **plugs a hole** in `split-shell-dependent-testplan`: that proposal's `XCTSkipUnless(bracketedPasteMode)` does **not** skip on zsh (capability present), so without this change the zsh arm would still red at `:82`. A one-line pointer is added to `split-shell-dependent-testplan`'s design (reverse duty) recording that the zsh matcher red is fixed here and that change only skips the bash execution arm — keeping the change-set coherent for the pre-archive critic.

### D5: Do not change the producer (grid dump stays physical rows joined with `\n`)

The "most faithful" fix — reconstructing logical lines from SwiftTerm wrap metadata — is rejected for the same reason `harden-findbar-wrap-assertion` D3 rejected it: `BufferLine.isWrapped` is `internal` in the pinned SwiftTerm `v1.13.0`, so it would cost another accessor on `patches/swiftterm/xtty-accessors.diff` and re-validate the dump format for every grid-reading test — disproportionate for DEBUG-harness value. The wrap-tolerant matcher is the right layer.

### D6: Reverse-duty tracker updates land in the same session

Per AGENTS.md, greening a documented rig residual obliges same-session tracker updates: correct + retire the `packer/README.md` "zsh grid-capture arm" matrix row (cause = prompt-width soft-wrap; residual → fixed) and flip the zsh-rig envelope `40/1/1` → `41/0/1`; update the `github-actions-ci-cd.md` §19b zsh cross-check note (the `:82` guarantee is now wrap-tolerant); correct `shell-dependent-test-partitioning.md` so the zsh `:82` red reads as a matcher fix (this change), not a split-plan skip candidate (only the bash `:87` execution arm is). These are implementation tasks, not afterthoughts.

## Risks / Trade-offs

- **The fix can't be proven on bare metal** — the local short-`\h` prompt never wraps, so the paste test passes strict there and the wrap case is not exercised. *Mitigation:* two paths. (1) The existing `testSoftWrapGuardIsWrapTolerant` exercises wrap-tolerance deterministically in `make test` regardless of prompt width. (2) The wide-prompt **zsh** VM rig *reproduces* the paste `:82` red, so this change is verified **red→green in-guest** (`40/1/1` → `41/0/1`), not only by argument.
- **Wrap-tolerance could mask a real "line didn't land" bug** → *Mitigation:* it stays opt-in and scoped to the two positive paste assertions; the tokens are unique single words that cannot span a hard break; an absent line still fails; the strict default remains the norm for other callers, and the `:87` negative check stays strict (D3).
- **Interaction with an in-flight change** (`split-shell-dependent-testplan`) → *Mitigation:* D4 — orthogonal lines, documented pointer, verified by the pre-archive change-set-aware critic pass.

## Open Questions

(none — the matcher and its deterministic guard both already exist; this change only routes two more assertions through them.)
