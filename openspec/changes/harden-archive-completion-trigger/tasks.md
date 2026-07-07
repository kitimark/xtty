## 1. Define the completion ritual + marker in the project guide

- [ ] 1.1 In `AGENTS.md` → "How to work here" → the **Keep progress current** rule: define the **standard change tail** (a pre-archive coherence task `⟶ xtty-openspec-critic`, then an **archive + reconcile** task `⟶ archive-ritual`) and state that `⟶ archive-ritual` resolves to the **committed** procedure (OpenSpec workflow "After archiving, finish the merge by hand" + Keep-progress-current + the `openspec archive` CLI), with the machine-local `/openspec-archive-change` skill an **optional accelerator**, never the committed anchor (design D1/D3). Note the marker is a **procedure pointer, not an agent delegation** (D2), so the coherence critic does not expect an agent for it. Add the **pre-tick self-check** (spec deltas merged, trackers reconciled, verify-against-disk ran).
- [ ] 1.2 In `AGENTS.md` → OpenSpec workflow → the "Keeping a change coherent" **`tasks.md`** checklist bullet: require that a change's completion carries the explicit marked archive + reconcile task (`⟶ archive-ritual`), mirroring the existing `⟶ xtty-test-validator` marker sentence, so `/opsx:propose` emits it and `xtty-openspec-critic` flags its absence.
- [ ] 1.3 Add a 4th `openspec/config.yaml` `rules.tasks` entry: author the completion task with the `⟶ archive-ritual` marker, deferring to `AGENTS.md` for the ritual (point-there, no restatement — matching the three existing rules).

## 2. Retrofit the open changes (make it live now)

- [ ] 2.1 Add an explicit **archive + reconcile** task carrying `⟶ archive-ritual` to the tail of each open change's `tasks.md` — `add-zsh-test-image`, `split-shell-dependent-testplan`, `add-ci-pipeline`, `add-openspec-critic-agent` — after its existing pre-archive coherence task where present (add one only if genuinely missing). No scope/requirement change to those changes; `add-openspec-critic-agent` (frozen "✓ Complete, pending archive") gains the task that unblocks its archive.
- [ ] 2.2 (verify, inline) `openspec validate --all` still passes for every retrofitted change (the added task is a checkbox, not a spec/requirement change). Cheap check — inline.

## 3. Spec delta

- [ ] 3.1 The `research-capture` spec delta (`specs/research-capture/spec.md`) MODIFIES "Documented capture-and-reconcile workflow with verify-against-disk" to require the point-of-tick archive task + committed-anchor rule (+ the two new scenarios). Confirm it pastes the **entire** established block. `openspec validate harden-archive-completion-trigger` passes. Cheap check — inline.

## 4. Capture the finding (reverse duty)

- [ ] 4.1 Write the process-forensics research doc under `research/03-analysis/` to the capture-depth bar: the mechanism (the apply loop reads only the task line; AGENTS-only rules don't reach it), the **gitignore evidence** (`git ls-files .claude/skills/openspec-archive-change/` empty; `.gitignore` tracks only `xtty-*`), the **scaffold-gap table** (archive vs the three delegation procedures), the fix, and the reusable guideline — *"the apply loop only reliably executes procedure written at the point-of-tick; a rule that lives only in AGENTS.md is reconstructed from memory or skipped."* Index it in `research/README.md`. If it settles a refutation worth never re-litigating, note it for the Learned-refutations list at archive.

## 5. Verify by effect + complete

- [ ] 5.1 (verify — coherence, pre-archive) Review this change for coherence against AGENTS.md's rulebook + disk state (incl. that the retrofit markers landed on the four open changes and the MODIFIED block is a superset). ⟶ xtty-openspec-critic (harden-archive-completion-trigger)
- [ ] 5.2 (verify — by effect, hold-open) The **primary** proof: on the next archive driven from a `⟶ archive-ritual` marker (this change's own 5.3, or the next open change to archive), confirm the apply loop runs the full ritual — `openspec archive` (spec merge), finish-by-hand, tracker reconcile, verify-against-disk — **from the marker**, on a fresh/compacted context, without a user prompt. An improvised-anyway result is a clean failure justifying thread B (a committed `/xtty:archive` launcher), recorded as a follow-up rather than silently patched.
- [ ] 5.3 On completion, archive + reconcile trackers per AGENTS.md "Keep progress current": AGENTS.md Current-status row + snapshot (a new tooling entry; note the completion-ritual marker now standard), append the narrative to `HISTORY.md`, add a Learned-refutations one-liner if 4.1 warranted it, and verify against disk (`openspec list`, `ls openspec/changes/archive/`, `ls openspec/specs/`). ⟶ archive-ritual
