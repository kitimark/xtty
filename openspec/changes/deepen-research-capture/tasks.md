## 1. AGENTS.md (the rule source)

- [x] 1.1 Extend the "Write up research in `research/` when it's done" bullet with the capture-depth rule: the six-element anatomy (mechanism / reproducible probes incl. dead instruments / retired-theory fates table / re-verify-by-effect / optional generalized guideline / evidence artifacts), the scale-to-the-finding clause, and `local-network-privacy-forensics.md` named as the exemplar

## 2. Skill + command (the runnable form)

- [x] 2.1 `.claude/skills/xtty-capture-research/SKILL.md`: add a "Depth bar" sub-checklist to step 1 (compact, defers to AGENTS for the rule; names the exemplar); bump `version` to 1.1
- [x] 2.2 `.claude/commands/xtty/capture-research.md`: mention the depth bar in the launcher description (one clause, no rule duplication)

## 3. Validate + reconcile

- [x] 3.1 `openspec validate deepen-research-capture` passes; skim that the skill still satisfies the spec's "defers to AGENTS" scenario
- [x] 3.2 Add the change to AGENTS **Current open changes**; verify trackers against disk (`openspec list` / archive / specs)
