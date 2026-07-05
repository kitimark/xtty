## Why

The research-capture conventions specify the *packaging* of a capture (Provenance, Sources, ✅/❌/❓ tags, dated addenda, indexing, tracker reconciliation) but say nothing about **content depth**. The 2026-07-05 Local Network forensics capture (`research/03-analysis/local-network-privacy-forensics.md`) set the bar the owner wants as the norm: the settled **mechanism** (not just the conclusion), **reproducible probes** (copy-paste commands, what each proves/can't prove, dead instruments), a **theory-by-theory retraction record** (each ❌ next to the experiment that killed it), **re-verify-by-effect** steps, and — when the finding generalizes — a distilled **guideline**. Without codifying this, future captures regress to summary-only docs that can't be re-run, re-checked, or defended when a theory resurfaces.

## What Changes

- **AGENTS.md** (the source of truth the skill defers to): the "Write up research" convention gains a **capture-depth** rule — the anatomy above, explicitly *scaled to the finding* (a small landscape note doesn't need a probe catalog; any capture with measured claims or retired theories does), with the forensics doc named as the exemplar.
- **`.claude/skills/xtty-capture-research/SKILL.md`**: checklist step 1 gains a "Depth bar" sub-checklist (runnable form of the AGENTS rule, still deferring to AGENTS); version bumped.
- **`.claude/commands/xtty/capture-research.md`**: the launcher's one-paragraph description mentions the depth bar.
- **`research-capture` spec**: the documented-workflow requirement gains the depth conventions + a scenario.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `research-capture`: the "Documented capture-and-reconcile workflow with verify-against-disk" requirement additionally requires the documented conventions to include a capture-depth bar (mechanism, reproducibility, retraction record, effect-based re-verification, optional generalized guideline — scaled to the finding).

## Impact

- **Files:** `AGENTS.md`, `.claude/skills/xtty-capture-research/SKILL.md`, `.claude/commands/xtty/capture-research.md`, plus the spec delta. No product code, no build, no tests.
- **Behavior:** future `/xtty:capture-research` runs are guided to the deep form; existing docs unaffected (no retro-editing).
- **Risk:** over-prescription for small notes — mitigated by the explicit scale-to-the-finding clause.
