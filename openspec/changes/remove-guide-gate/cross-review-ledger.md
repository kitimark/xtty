# Cross-model design review — `remove-guide-gate`

**This ledger is advisory in its entirety. Nothing here gates archive.** Archive eligibility lives
solely in the human-attestation gate (AGENTS.md → `⟶ archive-ritual` step-0). "Converged" carries no
gate force; a dismissal is a proposal, not an accepted state; there is no receipt.

## Header (transparency contract)

- **Range:** base `375731ded75ca794b58f161cbb571e473346f088` (parent of the commit that added
  `proposal.md`) → HEAD `f24f1da36206361175cc87847cfebafc58b34cc9`. Single squashed commit.
- **Reviewed files (23):** `.githooks/pre-push`, `.github/workflows/ci.yml`, `AGENTS.md`,
  `HISTORY.md`, `Makefile`, `openspec/changes/remove-guide-gate/{.openspec.yaml,design.md,
  proposal.md,tasks.md,specs/agent-guide-budget/spec.md,specs/build-workflow/spec.md,
  specs/research-capture/spec.md}`, `research/03-analysis/agents-md-structural-best-practices.md`,
  `research/03-analysis/github-actions-ci-cd.md`, `research/README.md`,
  `research/artifacts/guide-gate/{README.md,install-hooks.sh,mutants.sh,pre-push,suite.sh}`,
  `scripts/{install-hooks.sh,test-guide-gate-mutants.sh,test-guide-gate.sh}`.
- **Passes run:** all three (A, B, C) — full run, not single-model.
- **Effective models:**
  - Pass A — `opus` (xtty-openspec-critic agent, definition stamp confirmed **v6 (2026-07-18)**,
    matched — not stale).
  - Pass B — `gpt-5.6-sol` (pinned via `--model`), effort **xhigh** (read from local
    `~/.codex/config.toml`: `model_reasoning_effort = "xhigh"`). Codex CLI `0.145.0`, companion
    resolved at `1.0.6`.
  - Pass C — `claude-fable-5` (self-attested in its output, matching the `model: fable` invocation
    parameter), effort inherited from this session (not invocation-pinned — the harness exposes no
    per-call override for the inline `Agent` tool).
- **Brief given to B and C:** identical, staged out-of-repo, five numbered claims-to-verify (archive
  migration-path actionability for other clones; the authoring clone's unverifiable-from-diff local
  cleanup; the "product code unchanged" claim; spec-delta completeness against the archived
  `bound-the-agents-md-guide` change; documentation reference hygiene) plus an explicit additive
  instruction to report anything outside the brief. Full text: staged at a `mktemp` scratch path,
  reproduced in this session's transcript.

## Round 1 fixes applied (post-ledger, main-loop, not re-reviewed by B/C)

Applied directly after this ledger was first assembled, at the human's request:

- **Archive-path deviation (BLOCKER/HIGH):** `tasks.md` task 3.4 now spells out the exact
  `--skip-specs` + hand-merge + `openspec validate --all --type spec` sequence in place of a plain
  `openspec archive` call. **Fixed.**
- **Migration-note wording (MEDIUM):** both `agent-guide-budget` and `build-workflow` REMOVED-requirement
  Migration notes reworded to lead with `git config --unset xtty.guide-gate` (the sufficient
  one-command disarm), then the version-proof hash-vs-own-recorded-stamp check for the optional file
  removal (not byte-identity to the deleted tracked source), then the `core.hooksPath` local-override
  case Pass B flagged. **Fixed.**
- **Missing Learned-refutations successor (MEDIUM):** added one atomic AGENTS.md bullet recording
  both directions — the mechanical gate was owner-retired (don't re-propose without new evidence) and
  advisory-only leanness was independently measured insufficient 3× (don't treat the surviving
  `research-capture` convention as proven sufficient). **Fixed.**

**Not yet addressed** (lower-severity Pass A findings, left open pending human direction): the
`AGENTS.md:98-99` markdown blank-line regression; `proposal.md`'s incomplete Impact list; the
"Shipped and archived" Tooling-row wording tension; the missing explicit Makefile-prerequisite-removal
verify task (spot-checked clean, but undocumented). `HISTORY.md`'s stale in-flight heading is correctly
deferred to the archive-reconcile step itself, not fixed here.

**This round of fixes was not re-run through Pass B/Pass C** — per the bounded fix→re-review loop,
a second full A‖B‖C round is available on request but was not auto-launched (Pass B has real cost per
run and this repo's protocol requires a human-initiated launch per run). `openspec validate
remove-guide-gate` passes post-fix. Re-validate the archive-path deviation for real before attestation
if you want stronger confidence than the sandboxed reproduction already on record above.

## Union findings (source-tagged, most severe first)

### 🔴 BLOCKER/HIGH — Archive is mechanically impossible as authored — **4-way independent confirmation**

**[Pass A · Pass B · Pass C · main-loop reproduction — HEURISTIC CONSENSUS, methodologically
independent, not brief-parroting]**

Removing all 8 `agent-guide-budget` requirements via `## REMOVED Requirements` leaves the capability
with zero requirements after OpenSpec's merge. OpenSpec 1.6.0's schema validator requires
`requirements.length >= 1` (`SPEC_NO_REQUIREMENTS: "Spec must have at least one requirement"`,
`spec.schema.js`). `openspec archive remove-guide-gate --yes` aborts globally:

```
Validation errors in rebuilt spec for agent-guide-budget (will not write changes):
  ✗ Spec must have at least one requirement
Aborted. No files were changed.
```

- Pass A reproduced this read-only in a scratch copy of `openspec/`.
- Pass B found it by reading the installed CLI's `buildUpdatedSpec`/`Validator` source directly.
- Pass C reproduced it independently in its own sandbox project on the same CLI version, and further
  showed the abort is **global** — a second capability's valid partial removal in the same run is
  also left unmerged.
- **I (main loop) independently reproduced it a fourth way:** created a disposable detached
  `git worktree` at `/tmp/xtty-scratch-verify` (never touched the real repo), ran
  `openspec archive remove-guide-gate --yes` there, got the identical abort message, confirmed zero
  files changed, then removed the worktree.

OpenSpec's delta grammar has ADDED/MODIFIED/REMOVED/RENAMED **requirements** only — no
capability-removal operation exists today. Task 3.4 (`⟶ archive-ritual`) will fail at its first act.
Pass C additionally verified a working escape path end-to-end:
`openspec archive -y --skip-specs` completes the archive move while leaving specs untouched, after
which the capability directory and the two other requirement removals must be applied by hand,
followed by `openspec validate --all --type spec`.

**Recommendation (converged across all four sources):** pre-write the exact deviation procedure into
`tasks.md`/`design.md` **before** the human attestation — `openspec archive remove-guide-gate -y
--skip-specs`; `rm -r openspec/specs/agent-guide-budget/`; hand-remove the 2 `build-workflow` +
1 `research-capture` requirements; `openspec validate --all --type spec`. Land this edit before
task 3.3's digest is computed (Pass A's sequencing point: `cross-review-digest.sh` hashes the whole
`B..HEAD` diff, so any later fix invalidates an already-recorded attestation — this repo's own
`cross-model-seat-assignment-research.md` refutation).

### 🟠 MEDIUM — Migration path for already-armed clones is unactionable, and worse than stated

**[Pass B · Pass C — heuristic consensus, both went materially beyond the shared brief with
non-overlapping detail]**

Both soundness passes confirmed brief claim 1 (the migration note references `.githooks/pre-push`
and hash-verification logic this same commit deletes) and then each added independent findings the
brief did not ask about:

- **Pass B:** the old installer also handled a `core.hooksPath` local-override case for users with a
  *global* hooks path; the migration note never tells those users to inspect/restore that override,
  potentially leaving their global hooks silently suppressed after removal.
- **Pass C:** the "byte-identical" predicate is not just unactionable but **wrong** for clones armed
  at any of the hook's 8 prior tracked revisions (a legitimately-owned older install is not
  byte-identical to the final version, so following the note as written would misclassify an owned
  hook as foreign and leave it armed). The actually-sufficient disarm is a single command —
  `git config --unset xtty.guide-gate` (the hook's own identity guard is
  `[ "$(git config --get xtty.guide-gate)" = true ] || exit 0`) — but no surviving current-facing
  text states that config alone suffices. Pass C also measured the risk as **imminent, not
  theoretical**: `AGENTS.md` is 49,069 B against the leftover hook's hardcoded default ceiling of
  51,770 B (5.2% headroom), and guide growth is now deliberately unbounded; a stale armed clone's
  refusal message would instruct reverting legitimate growth, never mentioning that the gate was
  retired.

**Recommendation:** reword both migration notes to lead with the one-command disarm
(`git config --unset xtty.guide-gate`), then give the version-proof ownership check for the optional
file removal (`git hash-object .git/hooks/pre-push` vs. that clone's own recorded
`xtty.guide-gate-hook-sha`, not byte-identity to a deleted file), then
`git config --unset xtty.guide-gate-hook-sha`. No standalone script needed — three documented
commands cover it correctly for every historical hook revision.

### 🟡 MEDIUM/REVIEW — Deleting the leanness refutation without a successor (cross-axis agreement)

**[Pass A (conformance) · Pass C (soundness) — same finding, found independently on a topic outside
the brief; not the protocol's defined B+C consensus flag, but notable since neither pass was primed
for this]**

The commit deletes the Learned-refutations bullet "AGENTS.md's leanness rule was overridden, not
unheard — the disease is admission, not reach... The fix is a mechanical gate below the agent"
outright, with no replacement one-liner. The *prescription* (the gate) is legitimately retired, but
the *measured finding* survives the gate's removal and is now unrecorded at the always-loaded
surface: advisory-only leanness failed three times, and a guard scoped to one surface displaces
growth rather than stopping it. The sibling refutation on the same subject (`A-15-7`/`A-C-5c`) was
instead *rewritten* with a HISTORY pointer — inconsistent treatment of two refutations from the same
investigation. Neither `proposal.md` nor `tasks.md` mentions removing a refutation (task 2.1 scopes
only to "live guide-gate instructions and CI claims").

**Recommendation:** at archive-reconcile, add one atomic Learned-refutations entry recording both
directions: the mechanical gate was owner-retired as not worth its maintenance surface (don't
re-propose without new evidence) **and** the advisory convention alone was measured insufficient
3×  (regrowth is now consciously accepted, not prevented) — don't cite the advisory convention as
if it were proven sufficient.

### 🟡 REVIEW — Other Pass A findings (single-source, spot-checked)

- **Markdown structure regression** (`AGENTS.md:98-99`) — confirmed by direct read: the deleted
  guide-gate bullet took its trailing blank line with it, so `Signing posture (P0): …` now sits
  directly under the preceding bullet with no blank line, rendering as a lazy continuation instead of
  its own paragraph. Cheap, mechanical, unintended by every artifact.
- **Evidence chain dead-ends** — `AGENTS.md`'s retained refutation pointer chain
  (→ `HISTORY.md` → `bound-the-agents-md-guide` narrative → `research/artifacts/guide-gate/README.md`)
  terminates at a deleted file. Declared as an accepted risk in `design.md` ("historical documents
  mention deleted artifact paths"), so disclosed-but-unrepaired, not a new gap.
- **`proposal.md` Impact list incomplete** vs. the landed diff — `HISTORY.md` and
  `agents-md-structural-best-practices.md` are modified but not listed under "Modified:"; conversely
  "OpenSpec specifications" is listed as modified but stays untouched until archive.
- **`HISTORY.md`'s in-flight heading will go stale** — "coherence COHERENT, pending human-attested
  archive" is now contradicted by the archive-blocker finding above; must be rewritten during the 3.4
  reconcile so the permanent log doesn't preserve a transient, now-false task count.
- **"Shipped and archived" Tooling row lost its guide-gate clause** — reads as a full category
  retirement, in tension with `proposal.md`'s stated intent to "preserve … records that the feature
  once shipped and was later removed," while the archived change directory itself remains on disk.
  Not a hard defect, a wording tension worth a human glance.
- **Verify-task breadth vs. the Makefile edit** — no task explicitly records checking the six routine
  targets after the `| hooks` prerequisite removal. Pass A spot-checked it live (`make -n build`,
  `make -n test-core`, `make help`) and found it clean — noting the gap in task coverage, not a live
  defect.

### 🟢 LOW — Pass C findings not independently re-verified (recorded as reported)

- **Git-internals discoveries in the deleted 556-line artifacts README** survive only in git history
  (`git show 375731d:research/artifacts/guide-gate/README.md`) and the archived change's `design.md`
  — a discoverability cost, not a loss, and a reasonable owner call per `design.md`'s own rationale.
  Pass C suggests a one-line HISTORY pointer to the recoverable commit would make this free.
- **Local-clone cleanup is corroborated by effect, not mechanically proven** — both Pass C and I
  independently checked the same facts (no `.git/hooks/pre-push`, no `xtty.*` config, no
  `core.hooksPath` at any scope). Pass C's framing: demanding a pre-deletion hash-comparison
  transcript would be verification theater for an owner-attested destructive operation on the owner's
  own clone; the worst case (a foreign hook wrongly deleted) is bounded by this clone being
  demonstrably armed via the routine auto-arm path. Recorded as corroborated-by-effect with a stated
  residual, not as mechanically proven.

### Disk-drift (Pass A)

- Open-changes table matches `openspec list` (`remove-guide-gate` 7/9, `add-ci-pipeline` 10/15). ✅
- All promised reverse-duty edits present (AGENTS.md, `research/README.md:68`, CI research record,
  structural-research retirement note). ✅
- Pre-existing, unrelated drift noted in passing: `research/03-analysis/openspec-coherence-checklist.md:19`
  says "26 of 58 archived changes"; disk is now 27 of 59 (introduced by the prior `375731d` archive,
  not by this change — out of scope for this attestation).

### Cross-change (Pass A, vs. `add-ci-pipeline`)

No shared-requirement collision — both changes touch `build-workflow` but over disjoint
requirements. Practical ordering note: both changes rewrite `.github/workflows/ci.yml` +
`research/03-analysis/github-actions-ci-cd.md`, so whichever archives second needs re-validation; and
`add-ci-pipeline`'s pending branch-protection step must not add `guide-gate` as a required check
(exactly what this change's own migration note asks for).

## Full verdict text per pass

- **Pass A:** `ISSUES-FOUND` — recommendation: fix-then-proceed.
- **Pass B:** `needs-attention` — "No-ship."
- **Pass C:** `needs-attention`.

---

**Restated: this ledger carries zero gate force.** Every finding above is advisory; every
"verified"/"confirmed"/"corroborated" label reflects reproduction depth, not archive permission. The
human reads this ledger, runs `scripts/cross-review-digest.sh remove-guide-gate`, and records the
attestation line in `tasks.md` task 3.3 themselves — the model must not compute, type, tick, or
commit that task. Given the 4-way-confirmed archive-blocker above, **fix the archive-path deviation
(and, if the human agrees, the migration-note wording) before running the digest**, since any commit
after attestation invalidates it.
