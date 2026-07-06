## Context

`testFindBarOpensLocatesAndDismisses` (`AppUITests/XttyUITests.swift:152–196`) opens the find bar, dismisses it, then types a `AFTERFIND<rand>` marker and asserts it reached the terminal grid — proving focus returned to the terminal rather than staying in the search field. The final assertion (`:192`) calls `GridDumpReader.waitForContains(marker, timeout: 5)` with the **strict** (default) matcher.

This is the *second* type-at-prompt-then-assert site to hit the soft-wrap hazard the sibling change `harden-focus-typing-assertion` already diagnosed and fixed at `:53`. Root cause (verified from `actions/runner-images` source — [`ci-runner-prompt-width-forensics.md`](../../../research/03-analysis/ci-runner-prompt-width-forensics.md)): the hosted runner's ~61-char hostname makes the stock `PS1='\h:\W \u\$ '` prompt long, so SwiftTerm soft-wraps the marker across two physical rows; `App/UITestDump.swift` joins physical rows with `\n`, and strict `waitForContains` does a raw `haystack.contains(needle)` — which a `\n`-split token can never satisfy. Focus **does** return (the CI investigator's rep-1 screenshot shows the insertion cursor after the marker inside the terminal pane); the marker is present, just wrapped. It is the §19b `findbar-marker-wrap` bucket.

The wrap-tolerant matcher already exists — `GridDumpReader.waitForContains(_:timeout:ignoringLineWraps:)` (`XttyUITestSupport.swift:153`), shipped by `harden-focus-typing-assertion`. This change consumes it; it introduces no new matcher.

## Goals / Non-Goals

**Goals:**
- Make the find-bar focus-restore assertion robust to terminal soft-wrap, so it passes when focus returns and the terminal wraps the marker, and fails only when the marker never arrives.
- Add a **deterministic** regression guard that reproduces the wrap class in `make test` on bare metal (independent of the ambient hostname/prompt), so the class cannot silently respawn.
- Keep the change **test-only** — no product code, no SwiftTerm patch, no new launch hook.

**Non-Goals:**
- The `bash32-no-bracketed-paste` paste residual — a different (shell-capability) fix, deferred.
- Long-`\h` VM prompt-width parity — its own change, `add-vm-prompt-width-parity`.
- Making `build-and-test` a required gate — it stays non-blocking; `test-core` stays the only required check.
- A producer-side "logical line" dump (see D3).

## Decisions

### D1: Apply the existing wrap-tolerant matcher at `:192` — reuse, don't reinvent

Change the `:192` assertion to `GridDumpReader.waitForContains(marker, timeout: 5, ignoringLineWraps: true)`, exactly mirroring `:53`. No new matcher, no app code. The marker is a unique random token, so normalizing wrap boundaries cannot fabricate a match; a genuine focus failure (marker routed to the search field) still leaves it absent from the grid → the assertion still fails. The strict default stays unchanged for its other callers.

### D2: The regression guard uses a guaranteed-wrap marker (self-validating) — NOT a new column-pinning launch hook

The guard must force a soft-wrap *deterministically*, without depending on the runner's long hostname (which is absent locally and on the VM). Two ways were considered:

- **(chosen) Type a marker wider than the focused pane.** A single contiguous token longer than the terminal's column count is guaranteed to soft-wrap at column 0 of the next physical row, producing the same `\n`-split-token phenomenon in the dump. The guard is **self-validating**: it asserts (a) the marker genuinely spans ≥2 physical rows (a strict `contains` of the whole marker returns *false* — the precondition that a wrap actually happened), and (b) the wrap-tolerant match returns *true*. If the marker unexpectedly does **not** wrap (a wider-than-expected window), (a) fails loudly — the guard can never pass without a real wrap. No app change, no launch argument, no dependency on window→columns font metrics.
- **(rejected) A `-UITestColumns N` launch hook** that pins the terminal to N columns. More faithful to the "normal marker + long prompt" shape, but it needs new product/harness code (a launch-arg-driven resize seam) for DEBUG-only value — disproportionate when a longer marker reproduces the identical dump phenomenon. This also dissolves the earlier open "can XCUITest pin columns?" spike: we don't need to.

The guard tolerates any reasonable default window width by choosing a marker comfortably wider than it (e.g. ≥ ~120 contiguous chars of a unique token) and self-validating the wrap; if a future window default grows past that, the guard fails loudly rather than silently passing.

### D3: Do not change the producer (grid dump stays physical rows joined with `\n`)

The "most faithful" fix — reconstructing logical lines from SwiftTerm wrap metadata — is rejected for the same reason `harden-focus-typing-assertion` D2 rejected it: `BufferLine.isWrapped` is `internal` in the pinned SwiftTerm `v1.13.0`, so it would cost a **third** accessor on the minimal `patches/swiftterm/xtty-accessors.diff` and re-validate the dump format for every grid-reading test — disproportionate for DEBUG-harness value. The wrap-tolerant matcher is the right layer.

### D4: Reverse-duty tracker updates land in the same session

Per AGENTS.md, retiring a §19b known-benign residual obliges same-session updates: move `findbar-marker-wrap` from residual → fixed in `github-actions-ci-cd.md` §19b, refresh the `packer/README.md` acceptance note (find-bar fixed), and add a dated "fix landed" line to the forensics doc. If this change is applied **after** `add-vm-prompt-width-parity` (the recommended red→green order), find-bar was the *reproduced red* on the wide-prompt VM and this change flips it green — the `packer/README.md` note records that, not "unchanged." These are implementation tasks, not afterthoughts.

## Risks / Trade-offs

- **End-to-end verification of the *find-bar* fix needs a wrapping prompt** — bare-metal/short-`\h` prompts don't wrap, so find-bar passes there trivially. *Mitigation:* two paths. (1) The D2 guard exercises the wrap-tolerance deterministically in `make test` regardless of prompt width. (2) If `add-vm-prompt-width-parity` is applied **first** (the recommended red→green order), the wide-prompt VM rig *reproduces* the find-bar wrap, so the fix is verified **red→green in-guest**, not only on CI. CI `build-and-test` remains the final confirmation (watched inline; classified via `xtty-ci-investigator` only if unexpectedly red).
- **A wider-than-expected default window could make the guard's marker not wrap** → *Mitigation:* the guard self-validates (asserts the wrap actually occurred via a failing strict match) and fails loudly if it didn't, prompting a longer marker — it can never pass vacuously.
- **Wrap-tolerance could mask a real wrapping bug** → *Mitigation:* it stays opt-in and scoped to the two focus assertions; the strict default remains the norm for ~15 other callers.

## Open Questions

(none — the column-pinning spike is dissolved by D2's guaranteed-wrap-marker approach.)
