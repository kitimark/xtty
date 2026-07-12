## Why

The cross-model-review archive gate shipped one day ago (`add-cross-model-design-review`) with a **blocking human-attestation task** as the mechanism that makes a human actually run the review before archive. **Nothing emits that task, and nothing blocks on its absence** — so for every change except the one that hand-wrote its own task during the dogfood, the gate is effectively inert.

Two independent gaps, both **measured on disk**:

- **Nothing emits it.** `openspec/config.yaml` carries a `rules.tasks` entry for all four existing point-of-tick markers (`⟶ xtty-test-validator`, `⟶ xtty-ci-investigator`, `⟶ xtty-openspec-critic`, `⟶ archive-ritual`) and **none** for the human-attestation cross-review task. `/opsx:propose` reads `config.yaml`, not `AGENTS.md` — so the rule, which today lives only in guide prose, **never reaches the task author**. This is the repo's own G13 refutation ("a rule that lives only in AGENTS.md doesn't reach the `/opsx:apply` loop") reproduced exactly.
- **Nothing blocks on its absence.** `xtty-openspec-critic`'s gate-task check is `heuristic → REVIEW`, explicitly *"never a BLOCKER — the in-scope judgment is semantic"*, and REVIEW findings never block a coherent verdict. So a missing gate task cannot fail a review.

**Consequence, verified:** both open changes — `add-ci-pipeline` and `add-git-diff-wrap-toggle` — are mechanically **in scope** (`scripts/cross-review-scope.sh` → exit 10) and carry **zero** human-attestation tasks. Both violate the shipped `cross-model-review` spec, which says an in-scope change's tail **SHALL** carry exactly one such task. This very change reproduces the bug on itself: proposed before the fix exists, `/opsx:propose` did not emit its own attestation task either.

The gate still fail-closes at archive (step-0 check (1) finds no attestation line), so this is **not a security hole** — it is a *"the tool doesn't work when used"* defect: the human is never *prompted* to run the review and discovers the requirement only when archive refuses. By **G-TARPIT-4** (dev tooling is validated by building and using it) this is the highest-value class of finding, and it is the one that came from *using* the gate rather than reviewing its spec.

## What Changes

- **Emission (propose-time).** `openspec/config.yaml` gains a `rules.tasks` entry instructing the task author that a change **in scope for cross-model review** MUST carry, in its tail, exactly one **blocking human-attestation cross-review task** — placed after the coherence-review task and before the archive task — with its **human-only / model-MUST-STOP** wording. The rule **defers to AGENTS.md** for the scope boundary rather than restating it (matching the four existing rules).
  - It is **NOT** a delegation marker. AGENTS.md refutes an auto-firing `⟶ xtty-cross-review` marker: a paid review that must not fire on task-arrival is *neither* delegate-to-subagent *nor* run-inline, the only two things the point-of-tick grammar can express. The rule tells the **author** to write the task; the **task text** tells the model to stop.
  - The propose-time in-scope call is necessarily **semantic**, because the classifier is **retrospective** — it scopes from `git diff --name-only B..HEAD`, i.e. **paths already committed**. Before a change's implementation lands, its range holds only its own artifacts (all allowlisted), so the classifier returns a confident **false negative** (`exit 0`, "out of scope") rather than an abstention. Scope at propose is a *prediction about paths that do not exist yet*. So the rule SHALL be **fail-closed**: when in doubt, emit. Over-emission costs one strikeable task; under-emission is this bug.

- **Enforcement.** `xtty-openspec-critic`'s gate-task check becomes **classifier-driven**, with blocker force taken **only** from an in-scope verdict, since only that verdict is positively informative: **exit 10** ⇒ **BLOCKER** unless the tail carries *exactly one* correctly-positioned, correctly-worded attestation task (absent, **duplicated**, **misordered**, or mis-worded all block); **exit 0** or an **uncommitted** exit 2 ⇒ *not yet knowable to be in scope*, so a **semantic** judgment at most **REVIEW**, **never suppressed**, stating what the classifier returned; a **committed** exit 2 (a malformed range archive will also refuse) ⇒ **BLOCKED-PREREQUISITE**.

- **Migration.** `add-git-diff-wrap-toggle` gets the missing human-attestation task. **`add-ci-pipeline` is deliberately excluded** — it has no `⟶ xtty-openspec-critic` task to anchor against, its digest range is 315 files (98.4% foreign), and its remaining owner-step commits would restage the HEAD-dependent digest while check (4) forbids re-recording, making the task **unsatisfiable**. It is already `exit 10`, so the archive gate applies to it either way; excluding it strands nothing.

- **No new machinery.** No new script, no new agent, no new marker grammar. One config rule, one agent-check upgrade reusing an already-committed classifier, and two task-tail edits.

## Capabilities

### New Capabilities

<!-- none -->

### Modified Capabilities

- `cross-model-review`: the **archive-gate** requirement gains the obligation that the **task-authoring configuration** (the surface the propose loop actually reads) instruct emission of the blocking human-attestation task, fail-closed on an ambiguous propose-time scope call — so the gate task reaches change authoring instead of living only in guide prose.
- `coherence-review`: the **cross-review-gate-task check** changes from a heuristic REVIEW-only check to a **mechanical BLOCKER when the committed scope classifier resolves the change as in scope**, degrading to the semantic REVIEW when the classifier cannot resolve it (an uncommitted change).

## Impact

- **`openspec/config.yaml`** — one new `rules.tasks` entry (the fifth), deferring to AGENTS.md for the boundary.
- **`.claude/agents/xtty-openspec-critic.md`** — the gate-task check becomes classifier-driven; definition stamp bumps to **v5** (the delivery-check stamp must move on every edit, or the staleness probe lies).
- **`AGENTS.md`** — the change-tail rule states that the gate task is emitted by the task-authoring config and enforced mechanically pre-archive.
- **`openspec/changes/add-ci-pipeline/tasks.md`**, **`openspec/changes/add-git-diff-wrap-toggle/tasks.md`** — the missing human-attestation task appended to each tail (migration).
- **No product code, no tests, no harness surface.** This is dev-workflow tooling; no new observable app behavior, so no `verification-harness` delta.
- **This change *will be* mechanically in scope once its implementation lands** (it touches `openspec/config.yaml`, `.claude/`, and `openspec/specs/` — all outside the allowlist). At propose time the classifier reads **`exit 0` / out of scope**, because only its own artifacts have landed — **which is precisely the defect it fixes.** It therefore carries its own blocking human-attestation task, added **by hand** because the rule that emits it does not yet exist: the bug reproducing on itself.
- **Two hazards named but deliberately not fixed here** (both route to the base-resolution change): range pollution makes a digest range 33–315 files wide and HEAD-dependent; and the scope call is **blind to uncommitted implementation** — with real product code present but uncommitted the classifier reads `exit 0`, so step-0's *entire* four-check precondition (including the digest's dirty-tree refusal, which lives *inside* it) is skipped and archive proceeds. Both are **pre-existing**, shipped with the gate.
