## 1. Replace CLAUDE.md with a symlink

- [ ] 1.1 Remove `CLAUDE.md` as a regular file and create a symlink in its place: `git rm CLAUDE.md && ln -s AGENTS.md CLAUDE.md`.
- [ ] 1.2 Update `AGENTS.md:3` — `"CLAUDE.md imports it"` → `"CLAUDE.md symlinks to it"`.
- [ ] 1.3 Update `AGENTS.md:61` (repo-tree comment) — `# imports AGENTS.md (Claude Code entry point)` → `# symlink to AGENTS.md (Claude Code entry point)`.

## 2. Verify by effect

- [ ] 2.1 `readlink CLAUDE.md` resolves to `AGENTS.md`; `diff CLAUDE.md AGENTS.md` is empty (symlink resolves transparently).
- [ ] 2.2 `git add CLAUDE.md && git ls-files -s CLAUDE.md` shows symlink mode `120000`, not `100644` — satisfies the `agent-guide-parity` spec's tracked-as-symlink scenario.
- [ ] 2.3 `openspec validate "symlink-claude-md-to-agents-md"` passes (cheap mechanical gate — inline, not delegated).
- [ ] 2.4 Spot-check Claude Code's own load is unaffected: start a fresh session in this repo and run `/context` — the *Memory files* category should read ~unchanged (~12k tokens per `agents-md-context-budget.md` §6's existing baseline), not roughly doubled. Cheap, inline check — no VM tier or Tier-1 XCUITest suite involved, so no `⟶ xtty-test-validator` delegation applies.

## 3. Reconcile and archive

- [ ] 3.1 Pre-archive coherence review ⟶ xtty-openspec-critic (symlink-claude-md-to-agents-md) — confirm the `agent-guide-parity` spec delta is coherent with the proposal/design and no other tracker drifted.
- [ ] 3.2 Archive + reconcile ⟶ archive-ritual — merge the `agent-guide-parity` spec delta into `openspec/specs/`, fill in its `## Purpose` (archive stubs it as TBD), and finish the merge by hand per AGENTS.md → "After archiving, finish the merge by hand."
