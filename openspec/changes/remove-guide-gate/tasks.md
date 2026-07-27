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
- [ ] 3.3 **HUMAN-ONLY — MODEL MUST STOP:** the human runs `/xtty:cross-review remove-guide-gate`, reviews the resulting ledger, computes the reviewed-state digest in their own terminal, and records the attestation line; the model MUST NOT compute, type, tick, or commit this task
- [ ] 3.4 Archive the change, merge the retirement deltas, and reconcile all trackers after the human attestation is present and the archive preconditions pass ⟶ archive-ritual
