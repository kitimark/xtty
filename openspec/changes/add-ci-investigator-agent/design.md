## Context

CI-failure triage in this repo is currently manual and context-heavy. The recurring shape (established by a recent hand-investigation of a `build-and-test` red): pull the failing job log, check whether the triggering commit even touched product/test code, download and parse the `.xcresult`, export the captured attachments (grid dumps, screenshots), read the grid dumps against the relevant test source, and finally classify each red as a documented known-benign environment residual, a regression, or something unexplained. That investigation drew ~30–50k tokens of build/test/attachment noise into the working session to reach a two-line conclusion ("both reds are documented known-benign residuals; the failing job is non-blocking").

This is the same problem `xtty-test-validator` already solves for suite *execution*: isolate the noise in a subagent, classify against a repo-owned envelope, return a fixed-skeleton verdict. The two are mirror images — the validator **produces** evidence by running the suite; this agent **consumes** CI evidence an already-finished run produced. They share a spine (the expected-difference envelope, the report/deference conventions, observe-never-repair) but differ sharply in mechanics (no VM, no multi-minute launch/wait, no stranding risk).

Constraints that shape the design:
- Committed `.claude` tooling **must** be `xtty-*`-prefixed (agents) or under `.claude/commands/xtty/` (commands) — everything else under `.claude/` is gitignored (AGENTS.md → Conventions).
- The classification target for the *CI* environment (hosted `macos-26` runner) currently lives as prose in AGENTS.md's Learned-refutations list and `research/03-analysis/github-actions-ci-cd.md`; the VM matrix in `packer/README.md` is CI-irrelevant.
- `gh` CLI and `xcrun xcresulttool` are the available evidence tools; both already exist in the dev/runner environment.

## Goals / Non-Goals

**Goals:**
- A committed `xtty-ci-investigator` agent + `/xtty:investigate-ci` launcher that, given a CI run reference, returns a fixed-skeleton verdict classifying every failure, with the log/xcresult/attachment noise confined to the agent's context.
- Cover the whole CI-failure space: XCUITest reds (grid-dump forensics), build breaks, a red **required gate**, and pr-lint failures.
- A durably-recorded **CI expected-difference matrix** the agent defers to at run time (no hardcoded buckets).
- A watch-vs-investigate delegation boundary wired into AGENTS.md + `config.yaml`, carried to the apply loop by a per-task marker.

**Non-Goals:**
- **Fixing** anything — no edits to product/test/config code, no CI re-runs or cancellations. The agent diagnoses and classifies; humans/the main session decide on fixes. (A fix hint when it is obvious is a bonus, never part of the contract.)
- Re-running or watching CI (`gh run watch` stays cheap/inline).
- Release/notarization job coverage (not in CI yet — deferred).
- Replacing or merging with `xtty-test-validator` — it stays a separate agent.

## Decisions

### D1 — A separate agent, not an extension of `xtty-test-validator`
They share the envelope and report conventions but almost nothing mechanically: this agent runs short read-only `gh`/`xcrun` calls, never boots a VM, never bridges a multi-minute launch/wait, and cannot strand a sweep. Folding CI-reading into the validator would drag the validator's turn-alive/babysitter/serialization apparatus onto a task that needs none of it. *Alternative considered:* one agent with a mode flag — rejected; the two share a **document** (the envelope), not a control flow.

### D2 — Model: ship on Sonnet, tune toward Haiku by measurement
Frontmatter `model: sonnet` (a frontmatter default, distinct from a per-call override, so it sticks for fresh spawns). Classification is largely a lookup against a documented matrix — Haiku-plausible — but the highest-value insight in the reference investigation (spotting that a red was a one-line test-harness inconsistency by cross-referencing two test methods) needed multi-file reasoning. So: Sonnet now; drop to Haiku only if measured runs against known reds prove classification is purely table-lookup. This mirrors how the validator's defaults were settled by measurement, not opinion. Because runs are short and read-only, the validator's "resume drops the model override" hazard cannot bite here.

### D3 — Scope: any CI job failure, triaged by job type
The agent branches on the failing job:
```
required gate (test-core) red  → REGRESSION by default (it gates merges) → stop
build break                    → compile error + file:line, verbatim
XCUITest red (build-and-test)  → xcresult download → parse → export attachments
                                 → read grid dumps + test source → classify
pr-lint red                    → Conventional-Commit title finding
```
*Alternative considered:* XCUITest-only — rejected as too narrow; a build break or a red required gate would fall back to ad-hoc inline handling, defeating the "single entry point" value.

### D4 — The CI expected-difference matrix lives in `github-actions-ci-cd.md`
Clean split of the deference chain, parallel to the validator's:
```
AGENTS.md ................ rules (triggers, boundary, observe-never-repair)   ← both agents
packer/README.md ......... VM acceptance envelope + matrix   ← xtty-test-validator
github-actions-ci-cd.md .. CI expected-difference matrix     ← xtty-ci-investigator  [NEW table]
```
The new table pulls the hosted-runner known-benign buckets out of prose: each row = failing test/step → runner-specific cause → bucket, plus the required-gate/non-blocking job map. *Alternative considered:* put it in `packer/README.md` next to the VM matrix — rejected; that file is the VM's home and CI runs on hosted runners, not the VM.

### D5 — Regression pre-check via the triggering commit's changed-file set
Before deep forensics, the agent inspects the commit that triggered the run (its changed files) to decide whether product/test code was even touched. A **docs-only** commit whose reds all map to benign buckets short-circuits to a verdict without a full deep-dive (it still maps each red — it just doesn't over-investigate). A product/test-touching commit always gets the full evidence pass. Mechanism (design-level, kept out of the spec): `gh api repos/:owner/:repo/commits/<sha>` or a local `git show --stat <sha>` when the commit is present locally.

### D6 — Reuse the verdict vocabulary, add the job-severity axis
`IN-ENVELOPE` / `OUT-OF-ENVELOPE` / `REGRESSION` carry over verbatim (same envelope, same meanings). CI adds one orthogonal fact the verdict must state: **which job failed** — a red on the **required gate** is a stop by default regardless of bucket; a red on a **non-blocking** job is classified against the matrix and, if all reds are benign, is "expected, no action."

### D7 — Fixed-skeleton report with a definition stamp
Same stale-served-definition detector as the validator: the report's first line is a definition-version stamp the launcher checks against the file. The skeleton: stamp · verdict · run identity (id, failing job(s) + required-gate/non-blocking, triggering commit + whether it touched product/test code) · verbatim failures · per-failure classification (bucket or `UNEXPLAINED`, and any `UNEXPLAINED` forbids `IN-ENVELOPE`) · evidence paths · recommendation (proceed / stop-and-investigate / blocked-prereq).

### D8 — Deliberately lighter than the validator
No turn-alive invariant, no babysitter/resume protocol, no VM serialization — none apply to short read-only runs. Evidence persistence is a **convenience, not a survival mechanism**: the agent MAY drop the downloaded `.xcresult` + a short note under `~/Downloads/xtty-ci-poc/<run>/` for human follow-up, but nothing strands if it doesn't. The launcher's delivery check (definition stamp) is retained; the strand-recovery half is not needed.

### D9 — Trigger boundary: watch inline, investigate-a-red delegated
Parallel to the validator's iterate-vs-validate boundary: `gh run watch` / reading a run's status stays cheap/inline; *investigating a failed run* is delegated to `xtty-ci-investigator`, carried to the apply loop by a per-task marker `⟶ xtty-ci-investigator (<run>)`. AGENTS.md is the single source of the boundary; `config.yaml`'s `rules.tasks` and the marker only point there.

## Risks / Trade-offs

- **Haiku (if adopted later) misses cross-reference insights** → ship Sonnet; gate any Haiku switch on measured runs against known reds (D2). The core contract is classification, which is table-lookup; deeper fix-hints are explicitly a bonus, so a weaker model degrades gracefully.
- **The CI matrix drifts stale** when a test is added/removed or an environment fix lands → impose the same **reverse duty** the validator has on `packer/README.md`: any change that alters CI residuals updates the matrix in `github-actions-ci-cd.md` in the same session. Encode this as a requirement, not a hope.
- **`xcrun xcresulttool` CLI shape shifts across Xcode versions** → the agent reports a blocker rather than guessing if the tool output differs from what it expects; the commands it relies on are pinned in the agent definition.
- **`gh` auth / private-repo access missing** → a run it cannot fetch is a `blocked-prereq` finding (one-time human setup), not something to improvise around — mirrors the validator's blocked-prereq handling.
- **Over-trusting the docs-only short-circuit** → the short-circuit still maps every red to a bucket; it only skips *deep* forensics when all reds are already benign. A single `UNEXPLAINED` red cancels the short-circuit.
- **A required-gate red that is actually a flake reads as REGRESSION** → acceptable: `REGRESSION` is a *stop-and-look* signal for a human, never an automatic action. Over-flagging the merge gate is the safe direction.

## Migration Plan

Purely additive tooling; no product or runtime surface. To back out: delete `.claude/agents/xtty-ci-investigator.md` + `.claude/commands/xtty/investigate-ci.md` and revert the doc edits (AGENTS.md row/bullet, `config.yaml` pointer, the `github-actions-ci-cd.md` matrix). No data, no schema, no rollback sequencing.

## Open Questions

- Evidence-dir convention: `~/Downloads/xtty-ci-poc/<run>/` proposed (parity with the validator's `~/Downloads/xtty-vm-poc/...`) — confirm during apply.
- Whether the CI matrix table belongs inline in `github-actions-ci-cd.md` or as a short dedicated section with a `research/README.md` pointer — settle when writing it.
