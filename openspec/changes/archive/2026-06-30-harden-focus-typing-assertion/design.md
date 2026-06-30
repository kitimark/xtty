## Context

`testFocusTypingOnActivateWithoutClicking` asserts a real product behavior: after `app.activate()` with **no click**, typed text reaches the focused terminal. It types `XTTYFOCUS<rand>` then calls `GridDumpReader.waitForContains(marker)`. Locally it passes; on GitHub-hosted `macos-26` it fails deterministically.

Root cause (research §12, banner-free run `28467944762`): the runner's login prompt is ~72 chars (`<long-vm-hostname>:/ runner$ `), so the typed marker is pushed to the terminal's right edge and SwiftTerm **soft-wraps** it — `X` ends one physical row, `TTYFOCUS<rand>` continues on the next. `App/UITestDump.swift` writes the grid as physical rows **joined with `\n`** (`lines.joined(separator: "\n")`), and `waitForContains` does a raw `haystack.contains(needle)` (`AppUITests/XttyUITestSupport.swift`). So `…runner$ X\nTTYFOCUS<rand>` cannot contain the contiguous `XTTYFOCUS<rand>`. The marker *is* present and on-screen — focus works — so this is a **false negative** of the assertion representation, not a product or focus failure.

This is the only test that types **directly at the prompt** and asserts the grid. Other markers (`SPLITMARK`, `QUAKEMARK`, paste tokens, config sentinels) land at column 0 of a fresh output line and do not wrap, so they are unaffected. The hazard is latent for any future type-at-prompt test.

## Goals / Non-Goals

**Goals:**
- Make the focus-on-activate content assertion robust to terminal soft-wrap, so it passes when input arrives and the terminal wraps it.
- Preserve the test's negative power: a genuinely absent marker must still fail.
- Keep the change **test-only** — no product code, no SwiftTerm patch, no new dependency.
- Leave the strict default matcher unchanged for its other callers.

**Non-Goals:**
- The six Bucket-B Cmd-key/menu-delivery CI failures (split/new-tab/paste/emoji/find/churn) — deferred to a later `harden-xcuitests-for-ci`.
- Making the GUI `build-and-test` job a required gate — it stays non-blocking; `test-core` stays the only required check.
- A general-purpose, faithful logical-line dump (see Decision 2).

## Decisions

### D1: Fix on the reader side, scoped — a wrap-tolerant matcher used only where needed

Add an opt-in wrap-tolerant matcher to `GridDumpReader` (e.g. `waitForContains(_, timeout:, ignoringLineWraps: true)` or a sibling `waitForContainsAcrossWraps`). It normalizes the haystack by removing the soft-wrap row boundaries before the substring check. The focus test opts into it; the default `waitForContains` stays **strict** for its ~15 other callers, so their contracts are unchanged.

- **Why scoped, not a global change to `waitForContains`:** a global newline-strip would silently change matching semantics for every caller. Scoping keeps the intent explicit at the one call site that needs it.
- **Safety:** no current `waitForContains` caller passes a needle containing `\n`, and the focus marker is a unique random token, so normalizing wrap boundaries cannot create a false positive. The multi-line paste test checks `lineA`/`lineB` as separate unique tokens and does not depend on the `\n` between them, so it is unaffected even though it is not the consumer here.
- **Negative power preserved:** removing wrap boundaries cannot fabricate an absent marker, so a real focus failure still fails the assertion.

### D2: Do NOT change the producer (the grid dump) to emit logical lines

The "most faithful" fix would have `UITestDump.writeGrid` reconstruct logical lines — joining soft-wrapped continuation rows without a `\n` — using SwiftTerm's wrap metadata. **Rejected for now:** `BufferLine.isWrapped` is **internal** (not `public`) in the pinned SwiftTerm `v1.13.0`, so this would require a **3rd accessor** on the gitignored `patches/swiftterm/xtty-accessors.diff`. That patch is deliberately minimal (the 2 accessors that power a *shipping* feature); spending a SwiftTerm-patch accessor on DEBUG-harness-only value is disproportionate, and it would also change the dump format for every grid-reading test (re-validating CJK/emoji/resize). Revisit only if a second type-at-prompt test hits the same wall.

### D3: Document the dump representation at the source

Add a one-line comment in `App/UITestDump.swift` noting the grid dump is **physical rows joined with `\n`** (so soft-wrapped logical content is split). This makes the constraint discoverable for the next test author and records why the wrap-tolerant matcher exists.

## Risks / Trade-offs

- **A wrap-tolerant matcher could mask a real wrapping bug elsewhere** → Mitigation: it is **opt-in and scoped** to the focus test; the strict default stays the norm, so only this one assertion relaxes wrap-sensitivity (which is exactly its intent).
- **The latent hazard remains for future type-at-prompt tests** → Mitigation: the D3 comment documents the dump representation; D2 records the producer-side upgrade path if/when a second test needs it.
- **The fix cannot be verified end-to-end on a *local* machine** (local prompts are short, so no wrap occurs) → Mitigation: assert the matcher's wrap tolerance with a unit-style check against a synthetic wrapped grid string, and confirm on the next CI `build-and-test` run that the focus test flips green.

## Open Questions

(none — scope is intentionally narrow)
