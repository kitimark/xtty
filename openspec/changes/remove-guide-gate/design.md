## Context

The guide-gate is split across a tracked pre-push hook, a cannot-fail installer, automatic Makefile prerequisites, a CI regression job, two shell test harnesses, an established capability, and several documentation surfaces. Its CI job validates only an installation into CI's own ephemeral clone; enforcement on a real contributor machine depends on a local `.git/hooks/pre-push` file and repository-local config that are not removed by deleting tracked files.

This is repository-workflow tooling only. No application code, terminal behavior, or product test envelope is affected.

## Goals / Non-Goals

**Goals:**

- Remove all live guide-gate execution paths and their dedicated source/test/artifact bundle.
- Stop routine `make` commands from writing into `.git`.
- Retire the corresponding OpenSpec requirements and current documentation.
- Safely disarm this clone without deleting a foreign or hand-merged pre-push hook.
- Preserve enough history to explain that the feature existed and was deliberately removed.

**Non-Goals:**

- Replace the guide-gate with another guide-size check.
- Rewrite archived OpenSpec artifacts or erase prior HISTORY entries.
- Remove the remaining advisory convention that status text stays concise and full narratives live in `HISTORY.md`.
- Change product builds or tests.

## Decisions

### Delete the feature rather than disable only its CI job

The owner described the feature itself as not useful, not merely the CI representation. Keeping the hook, installer, tests, or spec after removing the job would retain nearly all maintenance cost and leave a hidden local push interception path.

### Remove dedicated artifacts; retain broader historical research with a retirement note

`research/artifacts/guide-gate/` exists solely to prove and document the removed implementation, so it is deleted. `research/03-analysis/agents-md-structural-best-practices.md` also records the earlier guide-structure investigations and refutations that predate the hook; it remains historical evidence but gains a prominent note that the mechanical gate was retired. Archived changes and old HISTORY entries remain immutable records, while current-facing guidance and CI documentation are updated.

### Retire requirements through delta specs

The complete `agent-guide-budget` capability is removed. The two hook-related `build-workflow` requirements and the mechanical-backstop requirement in `research-capture` are also removed. The advisory, category-bounded status convention in `research-capture` remains.

### Uninstall only a verified repository-owned local hook

Before tracked deletion, resolve the installed pre-push path and verify that it is byte-identical to `.githooks/pre-push` and that its hash matches `xtty.guide-gate-hook-sha`. Only that exact owned copy may be deleted. Then remove the two repository-local config keys. A mismatched or foreign hook is preserved and reported for manual handling.

### Do not add a replacement check

The removal is intentional simplification. CI returns to the product-facing `test-core` and `build-and-test` jobs, while the existing PR-title lint remains separate.

## Risks / Trade-offs

- **Agent-guide growth is no longer mechanically blocked** → The repository consciously accepts this; the bounded-status writing convention remains advisory.
- **An uninspected clone may retain its old installed hook** → Current-facing migration notes state that tracked deletion cannot reach `.git`; this clone is safely disarmed, and other clones can remove a byte-identical xtty-owned copy manually.
- **Historical documents mention deleted artifact paths** → Current documentation no longer links to them; archived artifacts and old HISTORY remain historical records and the new removal narrative explains the retirement.
- **Removing a local hook could destroy custom logic** → Cleanup is conditional on exact source and recorded-hash ownership checks; mismatches are never deleted.
