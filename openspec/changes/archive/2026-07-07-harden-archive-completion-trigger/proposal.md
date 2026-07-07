# Harden the archive + reconcile completion trigger (author completion tasks to archive)

## Why

The `research-capture` capability already mandates the completion ritual — reconcile the trackers (Keep progress current) and **verify against disk** — and AGENTS.md documents the archive mechanic ("`openspec archive`" + "After archiving, finish the merge by hand"). But the `fix-osc7-hostname-reverse-dns` apply (2026-07-08) measured that ritual failing to reach the apply loop: task 4.3 ("On completion, reconcile trackers … and verify against disk") folded archive into an implicit "on completion" clause with **no pointer to any archive procedure**, so the apply loop improvised `openspec archive` and **never reached for the `/openspec-archive-change` skill** the user expected — the archive step only ran correctly because the user intervened mid-apply ("you should load the /openspec-archive-change skill").

Root cause is an **affordance failure at the point of action**, not a missing rule — the same class the delegation-trigger forensics named. From a strict reading of the **committed** docs, `openspec archive` was *correct*: AGENTS.md names only the CLI (lines 164 + 183) and the `/openspec-archive-change` skill is **openspec-generated and gitignored** (`git ls-files .claude/skills/openspec-archive-change/` → empty; `.gitignore` tracks only `xtty-*` skills), so the skill preference was encoded in **no committed artifact** and no agent would reach for it by default. Three mechanisms, one confirmed empirically:

- The archive/reconcile rule lives in `AGENTS.md` (loaded at session start) split across three places (Keep-progress-current + "After archiving…" + the Lifecycle rule); at apply time the loud, proximate instruction is the generic `/opsx:apply` skill ("make the changes, tick the box"), which models only *implement* tasks and merely "suggests archive." We cannot edit that generic skill.
- The completion task text carries no marker. **No open change's tasks.md carries any archive-procedure marker** (measured: 0). Every active change under-specifies its tail: `add-zsh-test-image` 7.1 / `split-shell-dependent-testplan` 7.1 name the reconcile but leave archive implicit; `add-ci-pipeline` 6.1 folds archive into a bare clause; `add-openspec-critic-agent` has **no archive task at all** and sits frozen "✓ Complete, pending archive" — the same failure, mid-flight.
- The archive + reconcile ritual is the **one recurring apply-loop procedure that never got the point-of-tick scaffold** the project built 3× for delegation (test-validation, ci-investigation, coherence-review): AGENTS.md boundary + committed tool + committed launcher + per-task marker seeded in `config.yaml`. Archive has a scattered boundary, a *gitignored* tool, no launcher, and no marker.

The correct surface is already proven by the delegation-trigger change: `openspec instructions apply` does **not** carry `config.yaml`'s `rules`, while `config.yaml` `rules.tasks` **does** surface at task-authoring time — so an archive marker can be seeded at propose and, once written into `tasks.md`, is the one signal that survives to the apply loop the generic skill drives.

## What Changes

- **Define the completion ritual and its per-task marker** in AGENTS.md's Keep-progress-current rule: name the **standard change tail** — (1) a pre-archive coherence task `⟶ xtty-openspec-critic`, then (2) an **archive + reconcile** task carrying the marker `⟶ archive-ritual` — and state that the marker points to the **committed procedure** (AGENTS.md → OpenSpec workflow "After archiving, finish the merge by hand" + Keep-progress-current + the `openspec archive` CLI), with the machine-local `/openspec-archive-change` skill an **optional local accelerator**, never the committed anchor. Add a lightweight **pre-tick self-check** (before ticking the archive task, confirm the spec deltas merged, trackers reconciled, and verify-against-disk ran).
- **Seed the marker at propose time** via a 4th `openspec/config.yaml` `rules.tasks` entry — a short instruction to author the completion task with the `⟶ archive-ritual` marker, **deferring to AGENTS.md** for the ritual (no restatement, single source of truth).
- **Add the archive-task marker to the "keeping a change coherent → tasks.md" checklist** (AGENTS.md) so propose emits it and the coherence critic catches its absence.
- **Retrofit the currently-open changes** — add an explicit marked archive + reconcile task to `add-zsh-test-image`, `split-shell-dependent-testplan`, `add-ci-pipeline`, and `add-openspec-critic-agent` (the last unblocks its frozen "pending archive" state) — so the fix is live for the **next** apply, not only future proposals.
- **`research-capture` spec delta**: strengthen the "Documented capture-and-reconcile workflow with verify-against-disk" requirement so the completion ritual is driven by a **point-of-tick archive + reconcile task** whose marker points to the committed procedure (not machine-local tooling), with scenarios for a marked completion task and for the marker-anchor-is-committed rule.
- **Capture the finding** as a process-forensics research doc (`research/03-analysis/`) to the depth bar (mechanism, the gitignore evidence, the scaffold-gap table, the reusable guideline — *"the apply loop only executes procedure written at the point-of-tick"*).
- **Verify by effect, hold-open** (primary): implemented-but-open until proven — this change's **own** archive task carries the new `⟶ archive-ritual` marker, so archiving it (or the next open change) must trigger the full ritual from the marker, on a fresh/compacted context, without a user prompt. An improvised-anyway result is a clean failure that justifies escalating to thread B (a committed `/xtty:archive` launcher), not a silent patch.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `research-capture`: the "Documented capture-and-reconcile workflow with verify-against-disk" requirement gains the **point-of-tick archive + reconcile task** convention and the **committed-anchor** rule — the observable contract that a change's completion is driven by a marked task (`⟶ archive-ritual`) reaching the apply loop, whose procedure anchor is committed (not the gitignored openspec-archive skill).

## Impact

- **Docs / workflow (no product code):** `AGENTS.md` (Keep-progress-current rule + the "keeping a change coherent → tasks.md" checklist); `openspec/config.yaml` (`rules.tasks`, a 4th entry).
- **Open changes retrofitted:** `add-zsh-test-image`, `split-shell-dependent-testplan`, `add-ci-pipeline`, `add-openspec-critic-agent` — an explicit marked archive + reconcile task added (no scope/requirement change to those changes).
- **Spec:** `openspec/specs/research-capture/spec.md` (one MODIFIED requirement, merged at archive).
- **Research:** a new `research/03-analysis/` process-forensics doc + its `research/README.md` line.
- **Not affected:** any product code / spec of a product capability; the three delegation agents/launchers (unchanged); `packer/README.md` numbers.
- **Deferred / out of scope (thread B):** a committed `/xtty:archive` launcher wrapping the openspec-archive skill (with a CLI fallback) — heavier, and the marker→committed-ritual already closes the gap; escalate only if the by-effect proof shows the inline ritual still gets skipped. Editing the generic `/opsx:apply` / `/opsx:archive` skills (not ours to own; the marker is the mechanism that reaches the generic loop instead).
