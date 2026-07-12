## Why

The cross-model-review archive gate (`add-cross-model-design-review`, archived 2026-07-12) uses a **blocking human-attestation task** as the mechanism that makes a human actually run the review before archive. **That obligation lives only in guide prose: nothing emits the task, and nothing blocks on its absence.**

**⚠️ The claim here is STRUCTURAL, not empirical — and an earlier draft overreached.** That draft said the gate is *"effectively inert"* for every change *"except the one that hand-wrote its own task"*. **Both halves are withdrawn** (see the dated record below): a **second** change has since carried the task and archived cleanly through the full gate, and the two changes that lack it **predate the obligation** — so there is **no clean evidence** the propose loop fails, in either direction. What remains, and what this change actually rests on, is that the obligation sits on a surface **the propose loop does not read**.

Two independent gaps, both **measured on disk**:

- **Nothing emits it.** `openspec/config.yaml` carries a `rules.tasks` entry for all four existing point-of-tick markers (`⟶ xtty-test-validator`, `⟶ xtty-ci-investigator`, `⟶ xtty-openspec-critic`, `⟶ archive-ritual`) and **none** for the human-attestation cross-review task. `/opsx:propose` reads `config.yaml`, not `AGENTS.md` — so the rule, which today lives only in guide prose, **never reaches the task author**. This is the repo's own G13 refutation ("a rule that lives only in AGENTS.md doesn't reach the `/opsx:apply` loop") reproduced exactly.
- **Nothing blocks on its absence.** `xtty-openspec-critic`'s gate-task check is `heuristic → REVIEW`, explicitly *"never a BLOCKER — the in-scope judgment is semantic"*, and REVIEW findings never block a coherent verdict. So a missing gate task cannot fail a review.

**Consequence, verified:** both open changes — `add-ci-pipeline` and `add-git-diff-wrap-toggle` — are mechanically **in scope** (`scripts/cross-review-scope.sh` → exit 10) and carry **zero** human-attestation tasks. Both therefore violate the shipped `cross-model-review` spec, which says an in-scope change's tail **SHALL** carry exactly one such task.

**⚠️ But that is a violation, NOT evidence the propose loop is broken — and an earlier draft of this proposal conflated the two.** Round 4 measured the dates:

```
add-cross-model-design-review  ARCHIVED 2026-07-12 (8950884)  ← the obligation ships here
add-ci-pipeline               proposed 2026-06-30 (c6ae3ea)   ← 12 days BEFORE
add-git-diff-wrap-toggle      proposed 2026-07-11 (0c454cd)   ←  1 day BEFORE
brief-cross-review-pass-b     proposed 2026-07-12 (155feb7)   ← the only POST-gate change
```

Neither open change could have emitted a task for an obligation that **did not yet exist**. They are evidence of a **retroactively-applied rule**, not of a broken loop. And the one change actually authored *after* the gate shipped — `brief-cross-review-pass-b` — **did** carry a correctly-worded, correctly-positioned attestation task in its propose commit (with `config.yaml` still at 0 cross-review hits), and archived cleanly through the gate.

**The honest record, stated plainly:** that data point is **also** confounded (it was a cross-review change authored in a gate-saturated session, and git cannot distinguish *"the loop emitted it from AGENTS.md context"* from *"a human hand-added it in the same commit"*). So there is **no clean evidence in either direction**, n=1 either way. **The severity claim is therefore narrowed:** the earlier *"the gate is inert / doesn't work when used"* framing is **withdrawn as unsupported**.

**What survives — and it is sufficient — is a structural argument, not an empirical one:** the obligation lives **only** in guide prose, and `/opsx:propose` reads `openspec/config.yaml`, not `AGENTS.md`. That is the repo's own **G13** refutation (*"a rule that lives only in AGENTS.md doesn't reach the loop"*), which was settled by measurement elsewhere and does not need re-proving here. Prose is a **fragile carrier**; `rules.tasks` is the **durable surface the propose loop provably reads** (verified: `rules.tasks` entries appear verbatim in `openspec instructions tasks --change … --json`). We are moving the obligation onto the surface that is actually read — regardless of whether the loop happened to get it right once by context.

The gate still fail-closes at archive (step-0 check (1) finds no attestation line), so this is **not a security hole**.

## What Changes

- **Emission (propose-time).** `openspec/config.yaml` gains a `rules.tasks` entry instructing the task author that a change **in scope for cross-model review** MUST carry, in its tail, exactly one **blocking human-attestation cross-review task** — placed after the coherence-review task and before the archive task — with its **human-only / model-MUST-STOP** wording. The rule **defers to AGENTS.md** for the scope boundary rather than restating it (matching the four existing rules).
  - It is **NOT** a delegation marker. AGENTS.md refutes an auto-firing `⟶ xtty-cross-review` marker: a paid review that must not fire on task-arrival is *neither* delegate-to-subagent *nor* run-inline, the only two things the point-of-tick grammar can express. The rule tells the **author** to write the task; the **task text** tells the model to stop.
  - The propose-time in-scope call is necessarily **semantic**, because the classifier is **non-attributive**: it scopes over `parent(proposal.md)..HEAD` — a **repo-wide** range — so it answers *"is some path in this range out-of-allowlist?"*, **never** *"is this change in scope?"* No answer it gives is about the change under review. So the rule SHALL be **fail-closed**: when in doubt, emit. The error direction is an extra obligation, never a missed review. *(⚠️ The earlier claim that over-emission "costs one strikeable task" is **withdrawn** — no striking procedure exists, and the new BLOCKER re-raises the task the moment it is removed. See design D5.)*

- **Enforcement.** `xtty-openspec-critic`'s gate-task check becomes **classifier-driven**, with blocker force taken **only** from an in-scope verdict, since only that verdict is positively informative: **exit 10** ⇒ **BLOCKER** unless the tail carries *exactly one* correctly-positioned, correctly-worded attestation task (absent, **duplicated**, **misordered**, or mis-worded all block); **exit 0** or an **uncommitted** exit 2 ⇒ *not yet knowable to be in scope*, so a **semantic** judgment at most **REVIEW**, **never suppressed**, stating what the classifier returned; a **committed** exit 2 (a malformed range archive will also refuse) ⇒ **BLOCKED-PREREQUISITE**.

- **Correct the classifier's description in the spec.** The established requirement calls it *"a mechanical classifier over **the change's changed paths**"* and says a change whose every changed path is allowlisted is out of scope. **Both are false** about the committed tool, which scopes over `parent(proposal.md)..HEAD` — a **repo-wide** range. It is **non-attributive** (an in-scope verdict cannot say *whose* path triggered it) and it **latches** (`openspec archive` always writes the non-allowlisted `openspec/specs/**`, so any change open across any archive is in-scope forever). Since this change is the one **promoting that verdict to BLOCKER force**, it must not archive a false description of it into `openspec/specs/`.

- **Migration — ⛔ escalated to the human, not decided here (design Q3).** An earlier draft decided to migrate `add-git-diff-wrap-toggle` and deliberately exclude `add-ci-pipeline` as *"unsatisfiable"*. **That premise is refuted** (its remaining work — a test PR and a GitHub repo *setting* — sits before its tail, so owner-steps → attest → archive is an ordinary ordering), and **both** open changes **predate the obligation**, making this a retroactively-applied rule. Three coherent options — migrate both, **grandfather** all pre-gate changes, or keep the split and accept a standing unclearable BLOCKER — are laid out in design **Q3**. **The human chooses.**

- **No new machinery.** No new script, no new agent, no new marker grammar. One config rule, one agent-check upgrade reusing an already-committed classifier, and one task-tail edit.

## Capabilities

### New Capabilities

<!-- none -->

### Modified Capabilities

- `cross-model-review`: **(a)** the **archive-gate** requirement gains the obligation that the **task-authoring configuration** (the surface the propose loop actually reads) instruct emission of the blocking human-attestation task, fail-closed on an uncertain propose-time scope call — so the gate task reaches change authoring instead of living only in guide prose. **(b)** the requirement's **description of the classifier is corrected**: it scopes over the change's **reviewed range** (repo-wide), not "the change's changed paths", and its verdict is **non-attributive**, **retrospective**, and **monotone under intervening archives** — so an in-scope verdict may be entirely foreign-driven and SHALL NOT be used as a proxy for "this change's implementation landed".
- `coherence-review`: the **cross-review-gate-task check** changes from a heuristic REVIEW-only check to one whose severity follows the authority of the scope call — a **BLOCKER** when the committed classifier resolves the change **in scope** (covering an absent, duplicated, misordered, or mis-worded task, and counting gate *tasks* rather than gate *mentions*); a **semantic REVIEW that is never suppressed** when it resolves the change **out of scope** (`exit 0` — *not yet knowable to be in scope*) or cannot resolve an uncommitted change; and a **blocked-prerequisite** when it refuses on a committed malformed range.

## Impact

- **`openspec/config.yaml`** — one new `rules.tasks` entry (the fifth), deferring to AGENTS.md for the boundary.
- **`.claude/agents/xtty-openspec-critic.md`** — the gate-task check becomes classifier-driven; definition stamp bumps to **v5** (the delivery-check stamp must move on every edit, or the staleness probe lies).
- **`AGENTS.md`** — the change-tail rule states that the gate task is emitted by the task-authoring config and enforced mechanically pre-archive.
- **`openspec/changes/add-git-diff-wrap-toggle/tasks.md`** — the missing human-attestation task appended to its tail (migration), in a commit **separate** from any later attestation (design D3). **`add-ci-pipeline` is deliberately excluded** (design D7) — its obligation would be unsatisfiable.
- **No product code, no tests, no harness surface.** This is dev-workflow tooling; no new observable app behavior, so no `verification-harness` delta.
- **This change *will be* mechanically in scope once its implementation lands** (it touches `openspec/config.yaml`, `.claude/`, and `openspec/specs/` — all outside the allowlist). At propose time the classifier reads **`exit 0` / out of scope**, because only its own artifacts have landed — **which is precisely the defect it fixes.** It therefore carries its own blocking human-attestation task, added **by hand** because the rule that emits it does not yet exist: the bug reproducing on itself.
- **Two hazards named but deliberately not fixed here** (both route to the base-resolution change): range pollution makes a digest range ~33–316 files wide, and it is HEAD-dependent (any commit anywhere restages it); and the scope call is **blind to uncommitted implementation** — with real product code present but uncommitted the classifier reads `exit 0`, so step-0's *entire* four-check precondition (including the digest's dirty-tree refusal, which lives *inside* it) is skipped and archive proceeds. Both are **pre-existing**, shipped with the gate.
