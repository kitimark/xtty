## 1. Remove execution paths

- [x] 1.1 Remove the `guide-gate` CI job, the `hooks`/`test-guide-gate` Makefile targets, and every automatic hook-install prerequisite from routine targets
- [x] 1.2 Delete the tracked pre-push hook, installer, fixture and mutation scripts, and the dedicated `research/artifacts/guide-gate/` bundle
- [x] 1.3 Safely remove this clone's installed hook and repository-local guide-gate config only after verifying tracked-source and recorded-hash ownership

## 2. Retire current documentation

- [x] 2.1 Remove live guide-gate instructions and CI claims from `AGENTS.md`, `research/README.md`, and the CI research record
- [x] 2.2 Mark the broader structural research as historical for the retired gate, preserve archived records, and add a concise removal entry to the current project trackers

## 3. Verify and complete

- [x] 3.1 Run `make help`, `git diff --check`, targeted reference checks, and `openspec validate remove-guide-gate`
- [x] 3.2 Review proposal/design/specs/tasks and implementation coherence ⟶ xtty-openspec-critic (remove-guide-gate)
- [x] 3.3 **HUMAN-ONLY — MODEL MUST STOP:** the human runs `/xtty:cross-review remove-guide-gate`, reviews the resulting ledger, computes the reviewed-state digest in their own terminal, and records the attestation line; the model MUST NOT compute, type, tick, or commit this task
<!-- cross-review-attestation: base=375731ded75ca794b58f161cbb571e473346f088 head=296de85dd286fcac6e82b57ad723645dcf104a07 digest=8c43ad73991237b804f28c085a0762dfc2e82e25524bf91413cb3249730f522f reviewed=2026-07-27 -->
- [x] 3.4 Archive the change using the verified whole-capability-retirement deviation, then reconcile all trackers, after the human attestation is present and the archive preconditions pass. **Deviation (required — a plain `openspec archive` aborts):** removing all 8 requirements of `agent-guide-budget` leaves it with zero requirements after merge, and OpenSpec 1.6.x's schema requires ≥1 (`Spec must have at least one requirement`) — reproduced 4 independent ways during cross-review (`cross-review-ledger.md`). Run, in order: (1) `openspec archive remove-guide-gate -y --skip-specs`; (2) `rm -r openspec/specs/agent-guide-budget/`; (3) hand-remove the two retired `build-workflow` requirements ("The clone arms its own repository hooks", "Continuous integration verifies the hook installer") and the one retired `research-capture` requirement ("The guide's leanness bound has a mechanical backstop and a refusal protocol") from their spec files; (4) `openspec validate --all --type spec`. Then finish the reconcile per the standard tail ⟶ archive-ritual. **Done 2026-07-27:** all four deviation steps executed exactly as specified (`openspec archive remove-guide-gate -y --skip-specs` moved the change to `openspec/changes/archive/2026-07-27-remove-guide-gate/`; `openspec/specs/agent-guide-budget/` deleted; the 2 `build-workflow` + 1 `research-capture` requirements hand-removed; `openspec validate --all --type spec` → 24/24 passed, `agent-guide-budget` correctly absent from `openspec list --specs`). Trackers reconciled in the same session (AGENTS.md open-changes row removed + snapshot updated, HISTORY.md entry finalized).
