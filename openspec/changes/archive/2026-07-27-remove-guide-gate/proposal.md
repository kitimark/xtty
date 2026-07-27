## Why

The guide-gate adds a large maintenance surface while its CI job only regression-tests an ephemeral installation and cannot establish that contributor clones are protected. The owner has judged that protection not worth the hook, installer, test harness, CI time, specifications, and dedicated documentation.

## What Changes

- **BREAKING** Remove the repository-managed `pre-push` guide gate and stop automatically installing it from routine `make` targets.
- Remove the `guide-gate` CI job, installer, fixture suite, mutation matrix, and their Makefile entry points.
- Remove the dedicated guide-gate artifact documentation and current project-guide instructions.
- Retire the established `agent-guide-budget` capability and remove the hook-installation/CI-verification requirements from `build-workflow`.
- Remove the mechanical-backstop requirement from `research-capture`; its advisory lean-status and history-preservation rules remain.
- Preserve archived OpenSpec changes and the historical narrative as records that the feature once shipped and was later removed.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `agent-guide-budget`: remove the capability because the repository will no longer mechanically gate agent-guide size at push time.
- `build-workflow`: remove the requirements to install repository hooks from routine targets and regression-test that installer in CI.
- `research-capture`: remove the requirement that its guide-leanness convention have a mechanical publication-boundary backstop.

## Impact

- Removed: `.githooks/pre-push`, `scripts/install-hooks.sh`, `scripts/test-guide-gate*.sh`, and `research/artifacts/guide-gate/`.
- Modified: `.github/workflows/ci.yml`, `Makefile`, `AGENTS.md`, `research/README.md`, the CI research record, and OpenSpec specifications.
- Retained as historical evidence: archived OpenSpec changes, prior HISTORY entries, and the broader `AGENTS.md` structural research, with an explicit retirement note so it is not mistaken for current workflow.
- Existing clones may retain an already-installed `.git/hooks/pre-push`; removal includes a safe cleanup step for this repository-owned copy because tracked-file deletion alone cannot remove files inside `.git`.
- Product code and terminal behavior are unchanged.
