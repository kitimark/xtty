# Cross-review ledger — fix-large-diff-memory-bound

Advisory only. Nothing in this file is read mechanically by any downstream step; archive eligibility is the human-attestation gate in `AGENTS.md` (`⟶ archive-ritual` step-0), computed from git, never from this ledger.

## Round 1

**Reviewed range:** base `0e0046b677b29e41a19faf7148876e20c4fbb637` (parent of the commit that added `openspec/changes/fix-large-diff-memory-bound/proposal.md`) → HEAD `b0672d3d0fd1d50cc0ce1c50498539f13438f035` at review launch.

**Reviewed file list:** `App/GitReviewView.swift`, `App/GitRunner.swift`, `App/TerminalWindowController.swift`, `AppUITests/XttyGitReviewUITests.swift`, `XttyCore/Sources/XttyCore/BoundedDiffOutput.swift`, `XttyCore/Sources/XttyCore/GitDiff.swift`, `XttyCore/Tests/XttyCoreTests/BoundedDiffOutputTests.swift`, `XttyCore/Tests/XttyCoreTests/GitDiffTests.swift`, `AGENTS.md`, `packer/README.md`, `openspec/changes/fix-large-diff-memory-bound/{proposal,design,tasks}.md` + `specs/*`, `research/03-analysis/known-product-issues.md`, `research/03-analysis/openspec-coherence-checklist.md`, `research/README.md`, `research/artifacts/large-diff-memory/{README.md,post-fix-2026-07-26.tsv,probe.sh}`.

**Passes run:** all three (companion resolved at `1.0.6`, `codex.available: true`, `auth.loggedIn: true` — Pass B ran, not skipped).
- **Pass A** — `xtty-openspec-critic`, Definition v6 (2026-07-18). Verdict: **COHERENT**. No blockers; 4 REVIEW items (task-hygiene notes, a stale evidence anchor, a VM-tier coverage gap, and a multi-capability wording nuance).
- **Pass B** — Codex, model `gpt-5.6-sol` (effort: project-config default, not independently confirmed). Verdict: **needs-attention**. 1 finding (high).
- **Pass C** — inline Fable 5, self-attested served model `claude-fable-5`. Effort inherited from the invoking session (numeric 80, not independently pinned). Verdict: **needs-attention**. 5 findings (0 critical/high, 2 medium, 3 low).

**Brief given to Pass B and Pass C (identical, staged out-of-repo via `mktemp`):** the design intent (bounding per-file Git-diff ingestion at the producer seam), 5 specific claims to soundness-check (accumulator boundary/priority arithmetic; binary-detection-vs-truncation interaction; process-lifecycle/grandchild-inheritance residual; RSS-probe evidence quality; the DEBUG-observation concurrency pattern), an explicit note that no independent runtime drills had been run beyond static reading, and the standing additive instruction to report anything outside the brief.

### Findings and disposition

| # | Pass | Severity | Finding | Disposition |
| --- | --- | --- | --- | --- |
| 1 | B | high | `--no-ext-diff --no-textconv` alone let a changed submodule with `diff.submodule=diff` configured recurse into the submodule's own nested diff content instead of the safe one-line `Subproject commit` summary; textconv/cleanup consequences also raised. | **Fixed** — added `--submodule=short` to all four Git invocations (3 preview calls + snapshot numstat). Own by-effect re-verification (a real-Git fixture) confirmed the recursion and its fix on Git 2.53 — **but round 1's own textconv-escape sub-claim was itself wrong; see round 2**. |
| 2 | C | medium | Filter drivers (`git-lfs`'s `filter.lfs.process`) and `core.fsmonitor` remain reachable external-command paths despite `--no-ext-diff`/`--no-textconv`. | **Documented, not code-fixed** in round 1 — **round 2 corrected the framing again** (see below); the residual is real but round 1's "bounded consequences" wording overclaimed. |
| 3 | C | medium | The RSS probe never exercised the 4 MiB `retainedBytes` cutoff — all fixtures fired `physicalLines`/`currentLineBytes` first; peak-growth figures (~5 MiB) didn't characterize the shape reaching the full ceiling. | **Fixed** — added a `wide`-line fixture (2,000-byte lines) at 10 and 40 MiB, reaching `retainedBytes`. Measured peak growth ~20.5 MiB, flat across the two sizes (`post-fix-2026-07-27.tsv`). |
| 4 | C | low | DEBUG observation (`lastDebugDiffProcess`) is process-global while `GitReviewController` is per-window; concurrent windows or same-path re-selection could show a stale/misassociated observation to a polling test. | **Dismissed** — narrow DEBUG/test-instrumentation-only hazard, not exercised by any current test. Reconfirmed acceptable in round 2. |
| 5 | C | low | Binary detection via substring-anywhere matching and glob-metacharacter pathspecs are pre-existing hazards (not introduced by this change), surfaced while checking the binary-vs-truncation interaction. | **Dismissed** — pre-existing, out of scope for this change's own claims. Reconfirmed acceptable in round 2 (Fable additionally flagged the glob-pathspec issue shares the submodule fix's own scope-assumption class — noted, not fixed, filed as a future follow-up). |
| 6 | C | low | Cutoff-reason priority ordering (`retainedBytes` → `physicalLines` → `currentLineBytes`) is a fixed check order; only the boolean, not the specific reason, reaches the parser/UI. | **Documented** — added a one-line clarifying comment in `BoundedDiffOutput.swift`'s `append(_:)` stating this is diagnostic-only by design. |

Pass A's 4 REVIEW items (task-hygiene, a stale evidence anchor on task 5.1, a VM-tier coverage gap, a spec cross-reference nuance) were **not actioned in round 1** — none were blockers, and round 2 folded the tasks.md hygiene concern into the round-1/2 task amendments (4.7/4.8) it needed anyway.

**Round bound:** 1 of 2 (N=2). Round 2 ran given the high-severity fix and the RSS-evidence gap warranted re-verification, and because round 1 itself needed to check whether its own submodule fixture's non-reproduction of the textconv sub-claim was sound.

## Round 2

**Reviewed range:** base `0e0046b677b29e41a19faf7148876e20c4fbb637` → HEAD `aeb8acb` at review launch (round 1's fixes committed: `App/GitRunner.swift` `--submodule=short`, `BoundedDiffOutput.swift` comment, `design.md`/`known-product-issues.md` updates, the extended RSS probe + new TSV, the submodule fixture).

**Passes run:** all three again.
- **Pass A** — `xtty-openspec-critic`, Definition v6 (2026-07-18). Verdict: **ISSUES-FOUND**. 3 BLOCKERs + several REVIEW items.
- **Pass B** — Codex, model `gpt-5.6-sol`. Verdict: **needs-attention**. 2 findings (both medium).
- **Pass C** — inline Fable 5, self-attested served model `claude-fable-5`. Verdict: **needs-attention**. 6 findings (0 critical, 1 medium raised to effectively high-impact by its own content, 2 more medium, 3 low).

**Brief:** round-1's 6 findings and their round-1 disposition summarized with file/line pointers, an explicit ask to verify each fix is *actually* correct (not just plausible) against current source, and the standing additive instruction.

### The headline finding: round 1's own textconv non-reproduction was itself wrong

**Both Codex (Pass B) and Fable (Pass C) independently found the same root cause**, unprompted by each other (this is genuine two-model corroboration, not shared-brief inflation — the brief only asked them to verify the round-1 disposition, it did not hint at a fixture bug): `submodule-diff-recursion-probe.sh` configured `diff.xtty.textconv` in the **origin** submodule repo *before* `git submodule add` cloned it. `git clone` never copies local repo config (only tracked files, so `.gitattributes` traveled but the driver setting did not) — so the recursed nested diff ran in a checkout with an attribute pointing at an unconfigured driver, making the sentinel's absence provable but meaningless. Round 1's "textconv did not escape on this Git version" claim, recorded in three committed docs, was a fixture artifact, not a Git-behavior finding.

**I independently re-derived this myself** (not merely trusting either model): reproduced the bug (confirmed the checkout's local config lacks the driver), then armed the driver in the checkout and reran — the sentinel **fired** in the pre-fix arm (textconv escapes the outer `--no-textconv` because the recursed diff is a separate `git diff` subprocess inheriting none of the outer invocation's suppression flags) and stayed absent in the fixed (`--submodule=short`) arm. The fixture was rewritten to configure the driver in the checkout and to **assert** both properties (not print for human eyeballing) — then mutation-tested by deliberately reintroducing the bug (dropping the flag), which the corrected script correctly caught (exit 1, three specific assertion failures).

**Consequence:** the shipped fix is more load-bearing than round 1 documented — it closes both a scope violation (a preview showing more than "one file's own diff") *and* a real configured-command-execution escape, not scope alone. All three docs that recorded the false negative (`known-product-issues.md`, `design.md`'s D5 addendum, the artifact README) were corrected.

### Findings and disposition

| # | Pass | Severity | Finding | Disposition |
| --- | --- | --- | --- | --- |
| 1 | B + C (independently, same root cause) | medium→**elevated** by what it overturns | Round-1 submodule fixture's textconv non-reproduction was a fixture bug (config not cloned), not a Git-behavior finding; the escape is real. | **Fixed** — fixture corrected (driver configured in checkout, both arms now asserted, not printed); three docs corrected; independently re-derived by the main loop itself, not just trusted; mutation-tested. |
| 2 | B | medium | Filter-driver/`fsmonitor` residual prose overclaimed "bounded consequences" — `GitRunner.runDiff` has no wall-clock timeout; the accumulator only engages once bytes cross a limit, so a stalling filter *before any output* is unbounded, and a non-conforming filter isn't guaranteed to exit on EOF. | **Fixed (doc correction)** — reworded to state honestly this is the same pre-existing "Git may allocate heavily before emitting stdout" residual, named as **unbounded**, not glossed as bounded. |
| 3 | A | BLOCKER | The `--submodule=short` guarantee existed only in `design.md`'s addendum, not in the `git-review` spec delta or `proposal.md` — `openspec archive` would merge a spec that never records it. | **Fixed** — added a new scenario to the `Bounded large-diff preview` requirement in `specs/git-review/spec.md`, extended the requirement body, and added bullets to `proposal.md`'s What Changes/Impact. `openspec validate --strict` passes. |
| 4 | A | BLOCKER | The submodule fixture printed for human eyeballing rather than asserting — both arms exited 0 unconditionally, so it could never fail (G-TARPIT-7). | **Fixed** — same fix as #1 above; the corrected fixture asserts and was mutation-tested. |
| 5 | A | BLOCKER | Task 4.4's Tier-1 evidence (`57/0/1 of 58`) predates the round-1 `App/GitRunner.swift` edit; `AGENTS.md`/`packer/README.md` quote it as current. | **Fixed** — delegated a fresh Tier-1 run (task 4.8) at the post-fix HEAD. First attempt hit a confound (a concurrent commit from this same session landed mid-build) and surfaced `testConfiguredNoWrapModeTogglesAndGeometryMatchesEachMode` red; the validator independently confirmed `--submodule=short` produces byte-identical diff output for an ordinary file, ruling out this change as cause. A second clean run on a stable tree passed **57/0/1 of 58**, matching the established envelope — the prior red was a non-reproducing timing flake in an unrelated pre-existing test, not a regression. |
| 6 | A | REVIEW | Tasks 2.4/4.2 read as though the round-1 additions never happened (already ticked, text unchanged). | **Fixed** — amended both tasks' notes; added task 4.7 (round-1/2 summary) and 4.8 (the Tier-1 re-run above). |
| 7 | A | REVIEW | `design.md` D6 still said "5/25/75 MiB" (four cases) and D2's "larger fixed multiple" was unquantified. | **Fixed** — D6 now names all shapes including wide-line; D2 now cites the measured ~20.5 MiB (~4×) figure. |
| 8 | A | REVIEW | `known-product-issues.md`'s probe-command paragraph still described "5/25/75 MiB + single line" right under a command that now runs six cases; the command itself pointed at a stale `.build/DerivedData/...` path `make build` doesn't produce. | **Fixed** — both corrected (six-case description; path corrected to `build/Build/Products/Debug/...` matching the Makefile's `DERIVED` variable). |
| 9 | A | REVIEW | No `specs/verification-harness/` scenario or XCUITest for the submodule guarantee — deleting `--submodule=short` turns nothing red in the harness proper. | **Escalated, not fully closed** — the git-review spec scenario was added (#3 above) and the real-Git fixture is now deterministic/mutation-tested (#1/#4 above), which Pass B explicitly said is sufficient ("a full XCUITest is not necessary if this real-Git regression is made deterministic"). No `AppUITests` XCUITest or `verification-harness` spec scenario was added — a submodule fixture is meaningfully more setup than the existing textconv sentinel test, and round-bound (N=2) pressure argued against adding one under time pressure this round. **The human should decide whether this is sufficient before archive, or whether to request follow-up UI-test coverage.** |
| 10 | C | low | Filter-driver residual: "protocol-conforming" qualifier needed even after correction. | **Superseded by fix #2** (the reworded "unbounded, no timeout" framing no longer makes a conformance-dependent safety claim at all). |
| 11 | C | low | Glob-metacharacter pathspecs share the submodule fix's own "one file's own diff" scope-assumption class. | **Dismissed for this change, filed as a future follow-up** — no configured-program-execution consequence, requires an adversarially-named file already in the user's own repo; the accumulator's memory bound holds regardless of how many files a glob pathspec matches. |
| 12 | C | low | Binary-detection substring-anywhere dismissal reconfirmed; noted it can misclassify a text diff whose own content quotes Git's binary-summary strings (pre-existing, orthogonal). | **Dismissed, reconfirmed out of scope** — same disposition as round 1. |
| 13 | C | low | `GitRunner.swift`'s class-level doc comment omitted `--submodule=short` from its flag inventory. | **Fixed** — comment updated. |
| 14 | C | low | The missing XCUITest gap's future form should specifically cover the armed-textconv arm, not just the recursion shape. | **Noted** — folded into finding #9's escalation and into `known-product-issues.md`'s explanation of why this stays script-only for now. |

**Round bound: 2 of 2 (N=2) — reached.** Per protocol, no further review rounds. The one escalated residual (#9) is stated plainly above, not looped on further.

---

**Escalated residuals (not fixed, final):**
- No `AppUITests` XCUITest or `verification-harness` spec scenario for the submodule-recursion/textconv-escape fix — covered instead by a self-asserting, mutation-tested standalone real-Git script (`research/artifacts/large-diff-memory/submodule-diff-recursion-probe.sh`). Pass B considers this sufficient; Pass A's coherence pass flagged the harness-coupling gap. The human should decide before archive.
- Glob-metacharacter pathspecs and substring-anywhere binary detection (`XttyCore/Sources/XttyCore/GitDiff.swift`) remain pre-existing, out-of-scope hazards, reconfirmed dismissed across both rounds.
- The unbounded (not "bounded") pre-first-byte residual — a configured filter, `core.fsmonitor`, or Git itself stalling before any stdout is emitted — is accepted as already covered by the design's original "Git may allocate heavily before emitting stdout" Risk, now named more precisely; no wall-clock deadline was added.

**Reminder (per protocol): "converged" has no gate force here. Every dismissal above is a proposal, not an accepted state, until the human reads this ledger. There is no receipt. The archive gate is the human attestation in `tasks.md`, computed independently from git by `scripts/cross-review-digest.sh`.**

**Sequencing note (per AGENTS.md's own attestation-fragility refutation):** `scripts/cross-review-digest.sh` hashes the repo-wide `B..HEAD` diff, so any commit anywhere in the repo before archive — including an unrelated `add-ci-pipeline` owner-step commit — invalidates an already-recorded attestation. Run task 5.2 and 5.3 back-to-back with nothing committed in between.
