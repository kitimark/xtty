# Known product issues — focused post-P7 audit

> **Provenance:** Captured 2026-07-26 from a read-only source and runtime audit performed 2026-07-25 against `9ece182111980fa6dc052b9cbb7ba99310c3cc50`. The audit traced the shipped App/XttyCore/SwiftTerm paths against the established OpenSpec requirements, ran focused Foundation/zsh probes, passed all **248/0/0** `XttyCore` tests, and completed a full `xtty` app build. No product code or OpenSpec artifact was changed. Claims marked ✅ are source-verified or probe-reproduced; ❌ marks a theory or assumption killed by evidence; ❓ marks an effect that still needs an end-to-end measurement.
>
> **Source scope:** [`App/GitRunner.swift`](../../App/GitRunner.swift), [`App/GitReviewController.swift`](../../App/GitReviewController.swift), [`App/TerminalWindowController.swift`](../../App/TerminalWindowController.swift), [`XttyCore/GitDiff.swift`](../../XttyCore/Sources/XttyCore/GitDiff.swift), [`XttyCore/OSC133.swift`](../../XttyCore/Sources/XttyCore/OSC133.swift), [`XttyCore/XttyConfigLoader.swift`](../../XttyCore/Sources/XttyCore/XttyConfigLoader.swift), [`XttyCore/ShellResolver.swift`](../../XttyCore/Sources/XttyCore/ShellResolver.swift), the bundled [`xtty-integration`](../../App/Resources/shell-integration/zsh/xtty-integration), pinned SwiftTerm [`Pty.swift`](../../external/SwiftTerm/Sources/SwiftTerm/Pty.swift), established specs under [`openspec/specs/`](../../openspec/specs/), and the tests named in §10.
>
> **KI-1 implementation addendum (2026-07-26):** `fix-large-diff-memory-bound` implements and measures the producer-side fix described in §2. The implementation is complete locally and awaits the human-only cross-review/archive gate; it is not yet an archived established-spec claim.

## 1. Headline and scope

The audit found **seven product defects** that the original green build and
unit-test envelope did not cover. KI-1 is fixed pending archive; **six remain
open**. Three affect core user behavior and three are lower-severity
configuration/refresh correctness defects.

| ID | Severity | Area | Finding | Evidence state |
|---|---|---|---|---|
| KI-1 | **High — fixed, pending archive** | Git review / memory | Per-file diff stdout is bounded while streaming; cutoff terminates and reaps Git | ✅ unit invariants + real-App RSS/process probe |
| KI-2 | **Medium** | Split focus / Git review | Mouse-click focus omits the required Git-review refresh | ✅ source construction; ❓ dedicated two-repo XCUITest pending |
| KI-3 | **Medium** | OSC 133 / Unicode | zsh command encoding corrupts every percent-encoded non-ASCII command | ✅ probe-reproduced |
| KI-4 | **Medium** | Profiles / cwd | A regular file passes `cwd` validation; failed `chdir` is silently ignored | ✅ source + filesystem probe |
| KI-5 | **Medium–low** | Git refresh | A visible non-repository pane still spawns Git every five seconds | ✅ source construction; ❓ process-count effect pending |
| KI-6 | **Low** | Configuration | CRLF line endings leave `\r` in values and section headers | ✅ probe-reproduced |
| KI-7 | **Low** | Configuration | `font-size = nan` survives parsing and range clamping | ✅ probe-reproduced |

This document is a **known-issues ledger, not a priority commitment**. KI-1 now
has the implemented OpenSpec change `fix-large-diff-memory-bound`; the other six
issues have no change ID. Future non-trivial fixes should start from the
established requirements and the verify-by-effect obligations in §8.

## 2. KI-1 — large-diff input is now bounded at the producer

### Original defect and measured scale

The Git-review UI could display at most 5,000 diff lines of at most 3,000
characters each, but selecting a very large text diff made xtty ingest and copy
the **entire** Git output before applying either cap:

```text
git child stdout
  → Pipe.readDataToEndOfFile()        # complete Data
  → String(decoding: data, ...)       # complete String
  → raw.split(...).map(String.init)   # complete [String] copy
  → emitted >= 5_000                  # first line-count stop
```

A disposable reproduction of that allocation shape grew peak memory by about
23.3, 111.8, and 321.6 MiB for 5, 25, and 75 MiB many-line inputs—roughly 4.3×
input. A bounded-reader prototype stayed near 3.3 MiB for all three. A
drain-and-discard prototype still spent about 26.9 MiB on one 25 MiB physical
line, proving that a record-count ceiling alone does not cover a missing-newline
adversary. Those exploratory figures establish the old scaling mechanism; they
are not portable budgets and did not deliberately force an OOM.

### Implemented mechanism

[`GitRunner.runDiff`](../../App/GitRunner.swift) now reads only per-file preview
commands in 64 KiB chunks through
[`BoundedDiffOutputAccumulator`](../../XttyCore/Sources/XttyCore/BoundedDiffOutput.swift).
It retains no more than 4 MiB, 5,008 physical LF records, or 16 KiB in the
current physical line. The generic complete-output runner remains unchanged for
record-oriented status, branch, and numstat queries.

Exact-limit EOF is complete: truncation is recorded only after observing an
additional byte. On an xtty-owned cutoff the App closes its read end, requests
SIGTERM, allows 250 ms, falls back to SIGKILL if necessary, and reaps the direct
Git child before publishing the bounded prefix. The producer cutoff is passed
to [`DiffParser`](../../XttyCore/Sources/XttyCore/GitDiff.swift) and ORed with
its model-side caps, including empty/header-only prefixes, so the panel always
offers “Diff too large — open in editor.”

Tracked, staged, and untracked preview commands now use `--no-textconv` as well
as `--no-ext-diff`. The latter disables external diff commands but does not
disable configured text-conversion drivers; a real-Git sentinel fixture killed
that assumption. Snapshot/numstat also uses `--no-textconv`, preserving binary
classification without executing the converter during panel refresh.

This bounds xtty's retained and subsequently materialized preview output. It
does **not** bound allocations Git performs internally before writing stdout;
that direct child remains the explicit residual.

### Reproducible probes and evidence

After a DEBUG build, run the real App-path probe from the repository root:

```sh
research/artifacts/large-diff-memory/probe.sh \
  .build/DerivedData/Build/Products/Debug/xtty.app/Contents/MacOS/xtty \
  /tmp/xtty-large-diff-memory.tsv
```

The script creates fresh repositories and app processes for exact 5/25/75 MiB
many-line inputs and a 25 MiB single line. It samples the App PID's RSS every
10 ms, waits for the real selected-diff state to report truncation, captures
the cutoff reason, and checks for matching preview Git children after
publication. Full mechanics and cleanup bounds are in the
[`large-diff-memory` artifact](../artifacts/large-diff-memory/README.md).

Recorded 2026-07-26 result
([TSV](../artifacts/large-diff-memory/post-fix-2026-07-26.tsv)):

| Input shape | Input | Peak xtty RSS growth | Publication | Cutoff | Git children |
| --- | ---: | ---: | ---: | --- | ---: |
| many-line | 5 MiB | 5,280 KiB | 458 ms | physical lines | 0 |
| many-line | 25 MiB | 5,120 KiB | 602 ms | physical lines | 0 |
| many-line | 75 MiB | 4,928 KiB | 734 ms | physical lines | 0 |
| single line | 25 MiB | 3,168 KiB | 455 ms | current-line bytes | 0 |

The 15× many-line input increase changed peak growth by only 352 KiB, both
cutoff shapes returned in under one second, and no preview child lingered. The
RSS slope is corroborating by-effect evidence, not a stable threshold:
allocator pooling and WindowServer state vary, the 10 ms sampler can miss a
shorter peak, and RSS includes shared pages. The deterministic proof is the
accumulator unit matrix: exact/over-limit behavior, arbitrary chunk boundaries,
all three cutoff reasons, and invariants across increasing offered input.

### Failed approaches

| Approach | Experiment / mechanism | Fate |
| --- | --- | --- |
| Parser-only cap | Complete `Data`, `String`, and line array existed before parsing | ❌ bounded only the returned model |
| Drain and discard after line cap | 25 MiB no-newline input still consumed about 26.9 MiB | ❌ failed the adversarial-record bound and delayed publication |
| Stop reading, then wait | A child can block forever writing into its full pipe | ❌ deadlock-prone; close/terminate/reap is required |
| `--no-ext-diff` alone | Configured textconv still ran and wrote its sentinel | ❌ textconv is a separate Git switch |

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
| KI-1 | Run `research/artifacts/large-diff-memory/probe.sh` against a fresh DEBUG build; increasing total output must leave peak-growth slope flat, both cutoff reasons must publish `truncated == true`, and the matching preview-child count must be zero |
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
| “Draining after a logical line cap handles every output shape.” | One 25 MiB no-newline record still consumed about 26.9 MiB | ❌ refuted — a current-physical-line byte limit is required |
| “Stop reading and wait for Git after reaching the cap.” | The writer can block on a full pipe after xtty stops draining | ❌ refuted — close, terminate, and reap the owned child |
| “`--no-ext-diff` disables configured textconv.” | A real fixture's converter wrote its sentinel until `--no-textconv` was supplied | ❌ refuted |
| “All pane-focus routes share `focusActivePane`.” | The click monitor updates focus independently and omits refresh | ❌ refuted |
| “Character-wise `%02X` is adequate percent encoding with a raw fallback.” | `éไทย😀` emits malformed UTF-8 encoding; Foundation returns `nil` | ❌ refuted |
| “An existing `cwd` path is a valid working directory.” | `/etc/hosts` exists but is not a directory; child `chdir` failure is ignored | ❌ refuted |
| “Once the store says non-repository, polling is inert.” | The timer calls `snapshot`, which begins with `rev-parse`, on every eligible tick | ❌ refuted |
| “`.whitespaces` removes a CRLF line's trailing `\r`.” | Foundation probe preserves `\r` | ❌ refuted |
| “The numeric range clamp sanitizes every parsed `Double`.” | NaN survives both `Double` parsing and the min/max clamp | ❌ refuted |
| “A green 248-test core envelope rules out these paths.” | The audit tests covered already-materialized diffs, keyboard focus, ASCII URLs, abstract cwd existence, LF config, and finite numbers | ❌ refuted — KI-1 needed producer tests; the post-fix core envelope is 260 |

## 10. Coverage map and baseline

| Area | Existing useful coverage | Missing discriminator |
|---|---|---|
| Git diff | `BoundedDiffOutputTests` prove producer limits; `GitDiffTests` prove source-truncation propagation; real-Git XCUITests cover many-line/single-line cutoff, opener routing, child cleanup, normal completeness, and textconv suppression | Git's own pre-stdout allocations remain outside xtty's bound |
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

KI-1 implementation verification:

- ✅ `make test-core`: **260 passed, 0 failed, 0 skipped**.
- ✅ Full App and XCUITest bundle build-for-testing succeeded.
- ✅ The real-App RSS/process probe produced the flat results in §2.
- ✅ The delegated isolated no-retry Tier-1 run was **57/0/1 of 58** with no
  capture-inactive/vacuous markers. Both large-diff cutoff shapes ran in fresh
  app/controller lifecycles, published truncation, drove the real open button,
  and reported their exact Git PID reaped and OS-absent; the textconv sentinel
  test also passed non-vacuously. Earlier non-acceptance runs exposed and retired
  two harness failures: same-bundle live-app interference and an XCUITest
  runner-side `/bin/ps` denied with `EPERM`.

## 11. Reusable guidelines

- **G-KNOWN-1 — Bound at the producer seam, not after materialization.** A parser cap cannot substantiate a memory-bound claim if the producer has already buffered the complete input.
- **G-KNOWN-2 — Every focus source must drive the same dependent-state transition.** Keyboard, mouse, tab, window, and programmatic focus are distinct event paths until a test proves they converge.
- **G-KNOWN-3 — Percent encoding is byte encoding.** Shell integrations must encode UTF-8 bytes and be tested as producer→consumer roundtrips; an ASCII-only consumer test is insufficient.
- **G-KNOWN-4 — Filesystem capability checks must validate the capability.** “Exists” does not imply “is a directory,” “is executable,” or “is writable”; validate the operation the child will perform and handle its failure.
- **G-KNOWN-5 — Empty/degraded UI state is not proof of zero background work.** Instrument process/query counts when a requirement says “no work.”
- **G-KNOWN-6 — Text configuration needs line-ending and numeric-domain fixtures.** Test LF/CRLF equivalence and reject non-finite floating-point values before applying range clamps.
- **G-KNOWN-7 — Bound the adversarial record as well as the stream.** A total-byte or record-count ceiling can still drain one unbounded no-newline record; keep a byte ceiling on the current physical record and terminate the producer at that seam.

## Sources

- **Product source at audit commit:** the files linked in the provenance/source-scope note and issue sections.
- **Established behavior:** [`git-review/spec.md`](../../openspec/specs/git-review/spec.md), [`terminal-semantics/spec.md`](../../openspec/specs/terminal-semantics/spec.md), [`terminal-configuration/spec.md`](../../openspec/specs/terminal-configuration/spec.md), and [`terminal-session/spec.md`](../../openspec/specs/terminal-session/spec.md).
- **Design intent:** [`p6-file-diff-decisions.md`](p6-file-diff-decisions.md), especially the visible/local/idle-gated refresh and large-diff cap decisions.
- **Tests inspected/added:** [`BoundedDiffOutputTests.swift`](../../XttyCore/Tests/XttyCoreTests/BoundedDiffOutputTests.swift), [`GitDiffTests.swift`](../../XttyCore/Tests/XttyCoreTests/GitDiffTests.swift), [`OSC133Tests.swift`](../../XttyCore/Tests/XttyCoreTests/OSC133Tests.swift), [`ShellResolverTests.swift`](../../XttyCore/Tests/XttyCoreTests/ShellResolverTests.swift), [`XttyConfigTests.swift`](../../XttyCore/Tests/XttyCoreTests/XttyConfigTests.swift), [`XttyMultiplexingUITests.swift`](../../AppUITests/XttyMultiplexingUITests.swift), and [`XttyGitReviewUITests.swift`](../../AppUITests/XttyGitReviewUITests.swift).
- **Focused probe outputs:** zsh 5.9 `_xtty_url_encode`; Foundation via the active Xcode Swift toolchain (`removingPercentEncoding`, CR trimming/number parsing, and NaN propagation), executed 2026-07-25.
- **KI-1 effect artifact:** [`research/artifacts/large-diff-memory/`](../artifacts/large-diff-memory/), executed 2026-07-26 against the implemented App path.
- **KI-1 Tier-1 acceptance:** `~/Downloads/xtty-vm-poc/artifacts/2026-07-26-fix-large-diff-memory-bound-task44-full-fresh-lifecycles/`; historical red evidence remains in the sibling `…-tier1`, `…-focused-redgreen`, `…-focused-app-census`, and `…-task44-isolated` directories.
