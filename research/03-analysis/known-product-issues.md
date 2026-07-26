# Known product issues — focused post-P7 audit

> **Provenance:** Captured 2026-07-26 from a read-only source and runtime audit performed 2026-07-25 against `9ece182111980fa6dc052b9cbb7ba99310c3cc50`. The audit traced the shipped App/XttyCore/SwiftTerm paths against the established OpenSpec requirements, ran focused Foundation/zsh probes, passed all **248/0/0** `XttyCore` tests, and completed a full `xtty` app build. No product code or OpenSpec artifact was changed. Claims marked ✅ are source-verified or probe-reproduced; ❌ marks a theory or assumption killed by evidence; ❓ marks an effect that still needs an end-to-end measurement.
>
> **Source scope:** [`App/GitRunner.swift`](../../App/GitRunner.swift), [`App/GitReviewController.swift`](../../App/GitReviewController.swift), [`App/TerminalWindowController.swift`](../../App/TerminalWindowController.swift), [`XttyCore/GitDiff.swift`](../../XttyCore/Sources/XttyCore/GitDiff.swift), [`XttyCore/OSC133.swift`](../../XttyCore/Sources/XttyCore/OSC133.swift), [`XttyCore/XttyConfigLoader.swift`](../../XttyCore/Sources/XttyCore/XttyConfigLoader.swift), [`XttyCore/ShellResolver.swift`](../../XttyCore/Sources/XttyCore/ShellResolver.swift), the bundled [`xtty-integration`](../../App/Resources/shell-integration/zsh/xtty-integration), pinned SwiftTerm [`Pty.swift`](../../external/SwiftTerm/Sources/SwiftTerm/Pty.swift), established specs under [`openspec/specs/`](../../openspec/specs/), and the tests named in §10.

## 1. Headline and scope

The audit found **seven open product defects** that the green build and unit-test envelope do not cover. Four affect core user behavior or the lean-memory requirement; three are lower-severity configuration/refresh correctness defects.

| ID | Severity | Area | Finding | Evidence state |
|---|---|---|---|---|
| KI-1 | **High** | Git review / memory | The 5,000-line diff cap runs only after the entire diff has been buffered and copied | ✅ source construction; ❓ peak-RSS effect not forced |
| KI-2 | **Medium** | Split focus / Git review | Mouse-click focus omits the required Git-review refresh | ✅ source construction; ❓ dedicated two-repo XCUITest pending |
| KI-3 | **Medium** | OSC 133 / Unicode | zsh command encoding corrupts every percent-encoded non-ASCII command | ✅ probe-reproduced |
| KI-4 | **Medium** | Profiles / cwd | A regular file passes `cwd` validation; failed `chdir` is silently ignored | ✅ source + filesystem probe |
| KI-5 | **Medium–low** | Git refresh | A visible non-repository pane still spawns Git every five seconds | ✅ source construction; ❓ process-count effect pending |
| KI-6 | **Low** | Configuration | CRLF line endings leave `\r` in values and section headers | ✅ probe-reproduced |
| KI-7 | **Low** | Configuration | `font-size = nan` survives parsing and range clamping | ✅ probe-reproduced |

This document is a **known-issues ledger, not a fix design or priority commitment**. None of the issues has an OpenSpec change ID yet. Future non-trivial fixes should start from the established requirements and the verify-by-effect obligations in §8.

## 2. KI-1 — the large-diff cap does not bound input or peak memory

### Symptom and impact

The Git-review UI can display at most 5,000 diff lines of at most 3,000 characters each, but selecting a very large text diff still makes xtty ingest and copy the **entire** Git output first. The cap therefore bounds the final model, not peak memory or the time spent materializing input. This conflicts with the product's lean-memory requirement and the P6 decision to cap large diffs.

An out-of-memory termination was **not** deliberately forced during this audit. The unbounded path is proved by construction:

```
git child stdout
  → Pipe.readDataToEndOfFile()        # complete Data
  → String(decoding: data, ...)       # complete String
  → raw.split(...).map(String.init)   # complete [String] copy
  → emitted >= 5_000                  # first line-count stop
```

### Mechanism

1. [`GitRunner.run`](../../App/GitRunner.swift) calls `readDataToEndOfFile()` and only then creates the returned `String`.
2. [`DiffParser.parse`](../../XttyCore/Sources/XttyCore/GitDiff.swift) receives that already-complete string and creates `rawLines` for the entire diff.
3. The `maxLines` check occurs inside the subsequent loop. Pre-hunk header lines are not counted by `emitted`, either, so even the parser's retained-output cap is not a strict cap over all parsed lines.
4. Both tracked and untracked per-file diff routes pass through this runner and parser.

### Reproducible source probe

```sh
nl -ba App/GitRunner.swift | sed -n '35,55p'
nl -ba XttyCore/Sources/XttyCore/GitDiff.swift | sed -n '87,145p'
nl -ba App/GitRunner.swift | sed -n '104,128p'
```

This proves the allocation order and the late stop. It does **not** measure allocator overhead, actual resident-memory peak, or the file size at which macOS kills the app.

### Coverage gap

`GitDiffTests` exercise `DiffParser` with an input `String` that the test has already materialized. They can verify the returned line count and `truncated` flag, but cannot prove that the producer stopped reading once the cap was reached.

## 3. KI-2 — mouse-click focus does not refresh Git review

### Symptom and impact

With two split panes rooted in different repositories and the Git-review panel open, clicking the other pane updates the active-pane model but does not request a Git refresh. The panel can continue showing the previous pane's repository until a later trigger—normally the five-second poll—runs.

### Mechanism

- The shared programmatic/keyboard focus path, [`focusActivePane`](../../App/TerminalWindowController.swift), calls `window.makeFirstResponder`, `registry.setFocus`, **and** `gitReview.refreshNow()`.
- The mouse monitor path, [`updateActivePaneFromClick`](../../App/TerminalWindowController.swift), assigns `activePaneID` and calls `registry.setFocus`, then returns without refreshing Git review.
- A click inside an already-key window does not need to produce a window-key transition, so no other immediate trigger is guaranteed.
- [`GitReviewController`](../../App/GitReviewController.swift) uses a five-second polling backstop, explaining the bounded-but-visible stale interval.

This violates the established requirement that the panel refresh **on focus change** in [`git-review/spec.md`](../../openspec/specs/git-review/spec.md).

### Verify the current effect

1. Open two splits and `cd` them into distinct repositories with distinguishable changed files.
2. Open Git review and focus repository A using the keyboard; wait until the state dump's `gitReview.repoRoot` is A.
3. Click pane B.
4. Observe `focusedPaneIndex` switch immediately while `gitReview.repoRoot` remains A until another trigger runs.

The missing call is ✅ source-verified. The four-step UI sequence is ❓ not yet encoded as an XCUITest or preserved as a state-dump artifact.

### Coverage gap

[`XttyMultiplexingUITests`](../../AppUITests/XttyMultiplexingUITests.swift) verifies directional keyboard focus. [`XttyGitReviewUITests`](../../AppUITests/XttyGitReviewUITests.swift) verifies repository/non-repository states, but no test combines **mouse focus + two repositories + visible Git review**.

## 4. KI-3 — zsh OSC 133 command encoding is not UTF-8 percent encoding

### Symptom and impact

Commands containing non-ASCII text—filenames, paths, comments, arguments, or programs—are captured in the block/session UI as malformed encoded text rather than the command the user typed. For example, `éไทย😀` becomes `%E9%E44%E17%E22%1F600`.

### Mechanism

[`_xtty_url_encode`](../../App/Resources/shell-integration/zsh/xtty-integration) iterates over zsh characters and formats each character's scalar-like numeric value using `%02X`. URL percent encoding instead operates over each **UTF-8 byte**:

- Expected `é`: `%C3%A9`
- Current `é`: `%E9`
- Expected `😀`: `%F0%9F%98%80`
- Current `😀`: `%1F600`

The current output is not a valid percent-encoded UTF-8 sequence. [`OSC133.parse`](../../XttyCore/Sources/XttyCore/OSC133.swift) correctly tries `removingPercentEncoding` and correctly preserves the raw value on failure, but that fail-soft behavior exposes the malformed producer output rather than recovering the original command.

### Reproducible probes

```sh
zsh -f -c 'source App/Resources/shell-integration/zsh/xtty-integration; _xtty_url_encode "éไทย😀"'
# %E9%E44%E17%E22%1F600

swift -e 'import Foundation; let s = "%E9%E44%E17%E22%1F600"; print(s.removingPercentEncoding as Any)'
# nil
```

The probes prove that the bundled producer emits an invalid sequence and Foundation cannot decode it. They do not exercise the entire terminal→OSC handler→sidebar rendering path.

The behavior conflicts with the decoded-command requirement in [`terminal-semantics/spec.md`](../../openspec/specs/terminal-semantics/spec.md).

### Coverage gap

[`OSC133Tests`](../../XttyCore/Tests/XttyCoreTests/OSC133Tests.swift) covers ASCII `cmdline_url` values such as `git%20status`. It tests the consumer, not the bundled zsh producer, and has no Unicode roundtrip fixture.

## 5. KI-4 — profile `cwd` validates existence, not directory-ness

### Symptom and impact

A profile with `cwd = /etc/hosts` is accepted as having a valid working directory even though the path is a regular file. The PTY child then fails to change directory, ignores that failure, and launches the shell in an inherited working directory. The user gets neither the requested directory nor the documented warning/fallback.

### Mechanism

1. [`ShellResolver.launchConfig`](../../XttyCore/Sources/XttyCore/ShellResolver.swift) injects `FileManager.default.fileExists(atPath:)` as its default `cwdExists` predicate.
2. [`expandCwd`](../../XttyCore/Sources/XttyCore/ShellResolver.swift) returns any path for which that predicate is true; it does not inspect `isDirectory`.
3. SwiftTerm's [`Pty.fork`](../../external/SwiftTerm/Sources/SwiftTerm/Pty.swift) executes `_ = chdir(cCurrentDirectory)` and discards the return code before `execve`.

### Reproducible probe

```sh
test -e /etc/hosts && echo "exists"
test -d /etc/hosts || echo "not a directory"
# exists
# not a directory
```

Together with the source path, this proves that the default validator accepts a path whose `chdir` must fail. It does not preserve an end-to-end shell `pwd` capture.

The behavior conflicts with the profile-working-directory contract in [`terminal-session/spec.md`](../../openspec/specs/terminal-session/spec.md): `cwd` is a directory and an invalid directory must warn and fall back.

### Coverage gap

[`ShellResolverTests`](../../XttyCore/Tests/XttyCoreTests/ShellResolverTests.swift) inject only an abstract true/false existence closure. There is no regular-file fixture and no assertion that the live child actually starts in the resolved directory.

## 6. KI-5 — non-repository Git polling still performs work

### Symptom and impact

When Git review is visible for a local directory that is not a repository, xtty launches `git rev-parse --show-toplevel` every five seconds. The UI correctly shows the non-repository empty state, but the refresh controller does not retain that state as a poll gate.

### Mechanism

1. [`setPolling(true)`](../../App/GitReviewController.swift) installs an unconditional repeating five-second timer while the panel is visible.
2. [`performRefresh(.poll)`](../../App/GitReviewController.swift) gates remote directories and running Git commands, but does not gate a cached `snapshot.isRepo == false`.
3. Every eligible tick calls [`GitRunner.snapshot`](../../App/GitRunner.swift), whose first operation is a new `git -C <dir> rev-parse --show-toplevel`.

This contradicts [`git-review/spec.md`](../../openspec/specs/git-review/spec.md), which says a non-repository focused session performs **no Git query** for the panel.

### Reproducible source probe

```sh
nl -ba App/GitReviewController.swift | sed -n '78,108p'
nl -ba App/GitRunner.swift | sed -n '59,66p'
```

This proves repeated dispatch from the timer to `rev-parse`. It does not count real child processes over time; that remains a ❓ instrumentation task.

### Coverage gap

The non-repository XCUITest asserts only the resulting `isRepo == false` state. There is no injected runner/process counter asserting that subsequent poll ticks do zero work.

## 7. KI-6 and KI-7 — configuration edge cases

### KI-6: CRLF line endings retain carriage returns

Both `parse` and `parseSections` split on `\n` and trim `.whitespaces`, not `.whitespacesAndNewlines`. Foundation does not include `\r` in the former set:

```sh
swift -e 'import Foundation; let value = "14\r"; let header = "[profile \"work\"]\r"; print(Double(value) as Any, value.trimmingCharacters(in: .whitespaces).debugDescription, header.trimmingCharacters(in: .whitespaces).debugDescription)'
# nil "14\r" "[profile \"work\"]\r"
```

Consequences:

- Numeric and Boolean values from CRLF files fail parsing and fall back with warnings.
- String-like values retain an invisible `\r` and may fail enum/name matching.
- A profile header retains `\r`, fails the anchored header regex, and its block is skipped as malformed.

See [`XttyConfigLoader.parse`](../../XttyCore/Sources/XttyCore/XttyConfigLoader.swift) and [`parseSections`](../../XttyCore/Sources/XttyCore/XttyConfigLoader.swift). The current configuration tests use LF input only.

### KI-7: non-finite font sizes survive the clamp

Swift accepts `Double("nan")`. The loader treats every successfully parsed `Double` as valid and clamps it with `min(max(...))`, but NaN propagates:

```sh
swift -e 'import Foundation; let value = Double("nan")!; let bounded = min(max(value, 6.0), 72.0); print(value.isNaN, bounded.isNaN)'
# true true
```

The resolved toolkit-independent configuration therefore carries a NaN font size without warning or fallback. No app crash was reproduced—AppKit may defensively substitute a font size—but the configuration violates its own finite `6...72` invariant and the invalid-value fallback requirement in [`terminal-configuration/spec.md`](../../openspec/specs/terminal-configuration/spec.md).

The existing tests cover unparseable input and finite values below/above the range, but not `nan`, `+/-infinity`, or other non-finite values.

## 8. Re-verify by effect

A future fix is not complete merely because a predicate or parser changed. Re-check the user-visible/resource effect:

| ID | Required effect check |
|---|---|
| KI-1 | Select a generated very-large text diff while sampling xtty RSS; peak growth must remain bounded independently of total Git output, the UI must report truncation, and Git/pipe handling must not deadlock |
| KI-2 | In a two-repository split, click the other pane and assert `focusedPaneIndex` and `gitReview.repoRoot` move to the same pane without waiting for the poll |
| KI-3 | Run a zsh command containing accented Latin, Thai, emoji, spaces, semicolons, and a newline-safe case; assert the block/sidebar command equals the original Unicode string |
| KI-4 | Launch a profile whose `cwd` is a regular file; assert a warning and the documented fallback directory, then launch a real directory and assert the child shell's `pwd` |
| KI-5 | Keep Git review visible in a non-repository directory for more than two poll intervals; an injected runner/process counter must remain unchanged after the initial classification |
| KI-6 | Resolve byte-identical LF and CRLF config fixtures and assert equal base/profile configuration with no CRLF-only warnings |
| KI-7 | Resolve `nan`, `inf`, and `-inf`; assert default font size plus one warning per invalid value, while finite out-of-range values still clamp according to the established contract |

## 9. Theory fates

| Theory / assumption | Evidence | Fate |
|---|---|---|
| “The 5,000-line parser cap bounds large-diff memory.” | Full `Data` + `String` + `[String]` are created before the line check | ❌ refuted — it bounds only the returned model |
| “All pane-focus routes share `focusActivePane`.” | The click monitor updates focus independently and omits refresh | ❌ refuted |
| “Character-wise `%02X` is adequate percent encoding with a raw fallback.” | `éไทย😀` emits malformed UTF-8 encoding; Foundation returns `nil` | ❌ refuted |
| “An existing `cwd` path is a valid working directory.” | `/etc/hosts` exists but is not a directory; child `chdir` failure is ignored | ❌ refuted |
| “Once the store says non-repository, polling is inert.” | The timer calls `snapshot`, which begins with `rev-parse`, on every eligible tick | ❌ refuted |
| “`.whitespaces` removes a CRLF line's trailing `\r`.” | Foundation probe preserves `\r` | ❌ refuted |
| “The numeric range clamp sanitizes every parsed `Double`.” | NaN survives both `Double` parsing and the min/max clamp | ❌ refuted |
| “A green 248-test core envelope rules out these paths.” | Tests cover already-materialized diffs, keyboard focus, ASCII URLs, abstract cwd existence, LF config, and finite numbers | ❌ refuted — the envelope is green but narrower than these claims |

## 10. Coverage map and baseline

| Area | Existing useful coverage | Missing discriminator |
|---|---|---|
| Git diff | `GitDiffTests` classify and cap returned diff models | Producer-side byte/RSS bound |
| Split focus | `XttyMultiplexingUITests.testDirectionalFocusMovesBetweenPanes` | Mouse focus tied to Git-review repo root |
| OSC 133 | `OSC133Tests` decode ASCII percent-encoded command text | Bundled-zsh Unicode roundtrip |
| Profile cwd | `ShellResolverTests` inject exists/missing results | Real-file-vs-directory validation and child `pwd` |
| Non-repo Git | `XttyGitReviewUITests` asserts empty state | Subsequent process/query count |
| Config | `XttyConfigTests` cover LF, invalid text, and finite clamping | CRLF equivalence and non-finite doubles |

Baseline recorded during the audit:

- ✅ `swift test` in `XttyCore/`: **248 passed, 0 failed, 0 skipped**.
- ✅ `xcodebuild -project xtty.xcodeproj -scheme xtty build`: succeeded.
- ✅ No tracked files were changed during discovery.
- ❓ The five-environment XCUITest acceptance envelope was not rerun; the authoritative repository snapshot remains the source for that envelope.

## 11. Reusable guidelines

- **G-KNOWN-1 — Bound at the producer seam, not after materialization.** A parser cap cannot substantiate a memory-bound claim if the producer has already buffered the complete input.
- **G-KNOWN-2 — Every focus source must drive the same dependent-state transition.** Keyboard, mouse, tab, window, and programmatic focus are distinct event paths until a test proves they converge.
- **G-KNOWN-3 — Percent encoding is byte encoding.** Shell integrations must encode UTF-8 bytes and be tested as producer→consumer roundtrips; an ASCII-only consumer test is insufficient.
- **G-KNOWN-4 — Filesystem capability checks must validate the capability.** “Exists” does not imply “is a directory,” “is executable,” or “is writable”; validate the operation the child will perform and handle its failure.
- **G-KNOWN-5 — Empty/degraded UI state is not proof of zero background work.** Instrument process/query counts when a requirement says “no work.”
- **G-KNOWN-6 — Text configuration needs line-ending and numeric-domain fixtures.** Test LF/CRLF equivalence and reject non-finite floating-point values before applying range clamps.

## Sources

- **Product source at audit commit:** the files linked in the provenance/source-scope note and issue sections.
- **Established behavior:** [`git-review/spec.md`](../../openspec/specs/git-review/spec.md), [`terminal-semantics/spec.md`](../../openspec/specs/terminal-semantics/spec.md), [`terminal-configuration/spec.md`](../../openspec/specs/terminal-configuration/spec.md), and [`terminal-session/spec.md`](../../openspec/specs/terminal-session/spec.md).
- **Design intent:** [`p6-file-diff-decisions.md`](p6-file-diff-decisions.md), especially the visible/local/idle-gated refresh and large-diff cap decisions.
- **Tests inspected:** [`GitDiffTests.swift`](../../XttyCore/Tests/XttyCoreTests/GitDiffTests.swift), [`OSC133Tests.swift`](../../XttyCore/Tests/XttyCoreTests/OSC133Tests.swift), [`ShellResolverTests.swift`](../../XttyCore/Tests/XttyCoreTests/ShellResolverTests.swift), [`XttyConfigTests.swift`](../../XttyCore/Tests/XttyCoreTests/XttyConfigTests.swift), [`XttyMultiplexingUITests.swift`](../../AppUITests/XttyMultiplexingUITests.swift), and [`XttyGitReviewUITests.swift`](../../AppUITests/XttyGitReviewUITests.swift).
- **Focused probe outputs:** zsh 5.9 `_xtty_url_encode`; Foundation via the active Xcode Swift toolchain (`removingPercentEncoding`, CR trimming/number parsing, and NaN propagation), executed 2026-07-25.
