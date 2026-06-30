## 1. Wrap-tolerant matcher (reader-side)

- [ ] 1.1 Add an opt-in wrap-tolerant matcher to `GridDumpReader` in `AppUITests/XttyUITestSupport.swift` (e.g. `waitForContains(_, timeout:, ignoringLineWraps: true)` or a sibling `waitForContainsAcrossWraps`) that removes soft-wrap row boundaries from the grid-dump text before the substring check; the existing strict `waitForContains` is left unchanged for its other callers.
- [ ] 1.2 Keep the negative guarantee: the matcher must still return false when the needle is genuinely absent (normalizing wrap boundaries must not fabricate a match).

## 2. Use it in the focus test

- [ ] 2.1 In `AppUITests/XttyUITests.swift`, change `testFocusTypingOnActivateWithoutClicking` to assert the typed marker via the wrap-tolerant matcher instead of the strict `waitForContains`.

## 3. Document the dump representation

- [ ] 3.1 Add a one-line comment in `App/UITestDump.swift` noting the grid dump is physical rows joined with `\n` (so soft-wrapped logical content is split across rows), pointing to the wrap-tolerant matcher as the reason.

## 4. Verify

- [ ] 4.1 Assert the matcher's wrap tolerance deterministically against a synthetic grid string where a known token is split across a `\n` boundary (present → matched) and against a string missing the token (absent → not matched), without needing a real wrapped CI prompt.
- [ ] 4.2 Run `make test` (or the `xttyUITests` action) locally to confirm no regression in the strict-default callers; note that local prompts are short so the wrap path is exercised by 4.1, and the end-to-end green flip is confirmed on the next CI `build-and-test` run.
