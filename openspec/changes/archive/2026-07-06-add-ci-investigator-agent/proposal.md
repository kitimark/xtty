## Why

Investigating a failed CI run is a **high-context, repetitive** activity: pulling the failing log, downloading and parsing the `.xcresult`, exporting attachments, reading grid dumps, checking whether the triggering commit even touched product code, then classifying each red as a known-benign environment residual, a regression, or something unexplained. Done by hand it floods the working session with tens of thousands of tokens of build/test noise (one recent investigation pulled ~30–50k tokens in to conclude "two documented known-benign residuals") and risks inconsistent classification. It is mechanical enough to delegate and standardize, and it maps almost 1:1 onto the existing `xtty-test-validator` pattern — isolate the noise, classify against the living envelope, return a fixed-skeleton verdict — approached from the opposite direction (reading an already-produced CI run instead of running the suite).

## What Changes

- **New committed agent `xtty-ci-investigator`** that, given a CI run URL/id, gathers the evidence (`gh run view` / `--log-failed`, the commit's changed-file set for a regression pre-check, `.xcresult` download + `xcrun xcresulttool` parse + attachment export, grid dumps, and the relevant test source) and returns a **fixed-skeleton verdict** — **observe-and-classify only, never repair**. It handles the whole CI-failure space: XCUITest reds (the grid-dump forensics flow), build breaks, a red required gate, and pr-lint failures.
- **New thin launcher `/xtty:investigate-ci`** (mirrors `/xtty:validate`): spawns the agent, forwards the run reference, relays the report, and does the definition-stamp delivery check.
- **New CI expected-difference matrix**, durably recorded in `research/03-analysis/github-actions-ci-cd.md` — the hosted-runner known-benign buckets (find-bar focus-marker prompt-wrap; multi-line paste under the runner's bash-3.2 with no bracketed paste) pulled out of prose into a table the agent defers to, next to the required-gate-vs-non-blocking job map.
- **Verdict vocabulary reused** (`IN-ENVELOPE` / `OUT-OF-ENVELOPE` / `REGRESSION`) plus a CI-specific axis: **which job failed** (required gate → a red is a stop by default; non-blocking → classify against the matrix).
- **Trigger boundary wired in** (AGENTS.md + `openspec/config.yaml`): *watching* CI (`gh run watch`) stays cheap/inline; *investigating a red run* is delegated, carried to the apply loop by a per-task marker `⟶ xtty-ci-investigator (<run>)`.
- **Model:** ships on **Sonnet**, to be tuned toward Haiku later only if measured runs prove classification is purely table-lookup (settle by measurement, not opinion).

## Capabilities

### New Capabilities

- `ci-investigation`: the committed `xtty-ci-investigator` agent + its `/xtty:investigate-ci` launcher, the CI expected-difference matrix it defers to, the fixed verdict-report contract (definition stamp, verbatim failures, per-red classification, required-gate/non-blocking awareness, evidence paths, recommendation), the two spawn scenarios (direct user request; verify/CI-task delegation with a per-task marker and a documented watch-vs-investigate boundary), and the observe-never-repair guardrails.

### Modified Capabilities

- (none) — the new agent's delegation boundary is part of `ci-investigation`; the existing `test-validation` capability is untouched.

## Impact

- **New tracked files:** `.claude/agents/xtty-ci-investigator.md`, `.claude/commands/xtty/investigate-ci.md` (both covered by the existing `.claude/agents/xtty-*` + `.claude/commands/xtty/*` gitignore exceptions).
- **Modified docs:** `AGENTS.md` (tooling-table row + the watch-vs-investigate delegation boundary bullet + committed-tooling list), `openspec/config.yaml` (`rules.tasks` pointer to the boundary), `research/03-analysis/github-actions-ci-cd.md` (the new CI expected-difference matrix), `research/README.md` line if the matrix warrants it.
- **Dependencies:** `gh` CLI (already used by CI) and `xcrun xcresulttool` (Xcode) — both already present in the dev/runner environment. **No product code and no runtime app behavior are touched.**
- **Relationship to `test-validation`:** parallel tooling sharing the classify-against-the-envelope discipline and the deference-chain/report conventions, but reading CI evidence rather than running the suite; the two consult different matrices (VM: `packer/README.md`; CI: `github-actions-ci-cd.md`) and both defer to AGENTS.md for rules.
