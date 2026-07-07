# Archive-trigger affordance forensics — why the completion ritual didn't reach the apply loop

> **Provenance:** 2026-07-08. Produced while proposing/applying `harden-archive-completion-trigger`, from a single measured failure on the `fix-osc7-hostname-reverse-dns` apply (same day) plus a static read of the committed docs, `.gitignore`, and `openspec/config.yaml`. Builds on and defers to [`dev-workflow-agent-orchestration.md`](dev-workflow-agent-orchestration.md) (the point-of-tick marker as the project's proven delegation-trigger surface) and [`claude-code-subagent-execution-forensics.md`](claude-code-subagent-execution-forensics.md) (the "affordance failure, not disobedience" framing this reuses). The actionable fix lives in the OpenSpec change; this doc is the *why* and the reusable guideline.

---

## TL;DR — the headline

The archive + reconcile ritual is documented in AGENTS.md (loaded at session start) but was **missing from the point of action** — the `tasks.md` line the `/opsx:apply` loop actually walks. On the `fix-osc7-hostname-reverse-dns` apply the completion task read *"On completion, reconcile trackers … and verify against disk"* — **no archive verb, no procedure pointer** — so the loop was never signalled to archive, improvised `openspec archive` when it got there, and reached the `/openspec-archive-change` skill the user expected **only after the user intervened mid-apply**. This is the same class the delegation-trigger forensics named: **the apply loop reliably executes only procedure written at the point-of-tick; a rule that lives only in AGENTS.md is reconstructed from memory or skipped.** The fix is the same the project already built 3× for delegation — a per-task marker (`⟶ archive-ritual`) seeded at propose via `config.yaml` — with one deliberate twist: the marker points to a **committed inline procedure**, because the obvious anchor (the archive *skill*) is gitignored.

## 1. The mechanism — why an AGENTS-only rule doesn't reach the apply loop

The `/opsx:apply` skill (a generic OpenSpec skill we do **not** own) walks `tasks.md` checkboxes and models only *implement* tasks — "make the change, tick the box"; on completion it merely *"suggests archive."* At apply time that generic skill is the **loud, proximate** instruction. AGENTS.md is the **distant** instruction: ~200 lines loaded once at session start, with the archive/reconcile rule split across three places (Keep-progress-current + the "After archiving, finish the merge by hand" subsection + the Lifecycle rule). The apply loop does **not** re-read AGENTS.md against its own prompt (measured earlier for the validator markers — `retire-metal-renderer` ran the Tier-1 suite inline, 0 autonomous delegations, until the marker was added at the point-of-tick). So the only signal that survives to the checkbox-walker is text **in the task line itself**.

- ✅ **Established surface:** `config.yaml` `rules.tasks` **does** reach the author at propose time (it is shown when artifacts are created), and once written into `tasks.md` the marker **is** the task line the apply loop reads. `openspec instructions apply` does **not** carry `config.yaml` `rules` — so the marker, not the rule, is what reaches apply. (This is exactly the delegation-trigger change's proven mechanism, reused.)

## 2. The measured failure (fix-osc7 archive, 2026-07-08) — ✅

`openspec/changes/archive/2026-07-08-fix-osc7-hostname-reverse-dns/tasks.md` task 4.3, verbatim:

> **4.3** On completion, reconcile trackers per AGENTS.md "Keep progress current": add/refresh this change's Current-status row + snapshot in `AGENTS.md` … append the dated narrative to `HISTORY.md`, add a one-liner to **Learned refutations** if warranted, and verify against disk (`openspec list`, `ls openspec/changes/archive/`, `ls openspec/specs/`).

The word *archive* appears only inside the `ls openspec/changes/archive/` **verify** path — the **action** of archiving (`openspec archive` + finish-by-hand spec merge) is folded into the bare **"On completion"** clause with no pointer to any procedure. Result (from the same task's completion note): the apply loop reached `/openspec-archive-change` **only** after the user intervened — *"you should load the /openspec-archive-change skill."* From a **strict reading of the committed docs, `openspec archive` was correct** (see §3), so this is not a wrong-answer bug — it is an **affordance failure at the point of action**: the expected procedure was encoded in no committed artifact reachable from the task line.

## 3. The gitignore evidence — the obvious anchor is uncommitted — ✅

The instinctive fix ("just write `⟶ /openspec-archive-change` into the task") points a **committed** file at an **uncommitted** tool:

```
$ git ls-files .claude/skills/openspec-archive-change/
                     # (empty — the skill is gitignored)
$ grep -n claude .gitignore
5:.claude/*
6:!.claude/commands/
7:.claude/commands/*
8:!.claude/commands/xtty/
9:!.claude/skills/
10:.claude/skills/*
11:!.claude/skills/xtty-*/     # only xtty-* skills are tracked
12:!.claude/agents/
13:.claude/agents/*
14:!.claude/agents/xtty-*
```

The `/openspec-archive-change` skill is **openspec-generated and machine-local** — the `.gitignore` un-ignores only `.claude/skills/xtty-*/`. The `research-capture` spec Purpose already classifies the openspec-generated commands/skills as ignored. So the user's expected tool exists on this machine but is invisible to a clone, CI, or another contributor. A committed `tasks.md` referencing it would be committed→uncommitted drift the coherence critic should flag. **⇒ the marker's anchor must be committed guidance, with the skill an optional local accelerator.**

## 4. The scaffold-gap table — archive vs the three delegation procedures — ✅

Archive is the **one recurring apply-loop procedure that never got the point-of-tick scaffold** the project built three times for delegation:

| Recurring apply-loop procedure | AGENTS.md boundary | Committed tool | Committed launcher | `config.yaml` marker seed | Point-of-tick marker |
| --- | :---: | :---: | :---: | :---: | :---: |
| Test-suite validation | ✅ | ✅ `xtty-test-validator` | ✅ `/xtty:validate` | ✅ | `⟶ xtty-test-validator` |
| CI-failure investigation | ✅ | ✅ `xtty-ci-investigator` | ✅ `/xtty:investigate-ci` | ✅ | `⟶ xtty-ci-investigator` |
| Coherence review | ✅ | ✅ `xtty-openspec-critic` | ✅ `/xtty:review` | ✅ | `⟶ xtty-openspec-critic` |
| **Archive + reconcile** (before this change) | ⚠️ scattered ×3 | ❌ *gitignored* skill | ❌ | ❌ | ❌ |

Archive differs from the three in one way that shapes the fix: it is **not** a context-flooding delegation. The ritual runs **inline** and produces the very tracker edits the session must own (AGENTS row, snapshot, HISTORY, milestones, the spec merge) — there is nothing to hand to a subagent. So the fix borrows the **marker**, not the **agent**: `⟶ archive-ritual` is a *procedure pointer, not an agent delegation*.

## 5. The fix

Give every change the same recognizable **standard change tail** so the ritual reaches the checkbox-walker:

```
 [ pre-archive coherence ]  ⟶ xtty-openspec-critic (<change>)
 [ archive + reconcile   ]  ⟶ archive-ritual
        ├─ openspec validate → openspec archive (merge spec deltas + move)
        ├─ finish-by-hand: new-spec Purpose, correct merged text, validate --all --type spec
        ├─ reconcile: AGENTS row+snapshot, HISTORY narrative, milestones, Learned-refutations
        └─ verify-against-disk: openspec list / ls changes/archive / ls specs
```

- `⟶ archive-ritual` resolves to the **committed** procedure — AGENTS.md → "After archiving, finish the merge by hand" + "Keep progress current" + the `openspec archive` CLI. The gitignored `/openspec-archive-change` skill is an **optional local accelerator** when present, never the committed anchor.
- Seeded at propose via a 4th `config.yaml` `rules.tasks` entry (deferring to AGENTS.md — no restatement, single source of truth), so **future** proposals emit it; the four open changes are **retrofitted** so it is live now.
- A **pre-tick self-check** (spec deltas merged, trackers reconciled, verify-against-disk ran) mirrors the validator's.

## 6. Fates table — retired theories

| Theory / alternative | Fate | Killed by |
| --- | :---: | --- |
| The apply loop *disobeyed* a known rule | ❌ | Committed-docs read: `openspec archive` **was** correct per AGENTS.md (names only the CLI); the skill preference was in **no** committed artifact — an affordance gap, not disobedience (mirrors the subagent-strand "affordance, not disobedience" finding). |
| Fix by writing `⟶ /openspec-archive-change` into the task | ❌ | §3 — the skill is gitignored (`git ls-files` empty); a committed→uncommitted reference is fragile across clones/CI/contributors and is coherence drift. |
| Build a new archive **agent** (4th `xtty-*`) | ❌ | §4 — archive is an inline checklist producing the session's own tracker edits (no context to isolate); AGENTS.md's "don't pre-build tooling / add an agent only after proven, provably under-done friction" refutation applies. |
| Edit the generic `/opsx:apply` / `/opsx:archive` skill to force the ritual | ❌ | Not ours to own; the marker reaches the generic loop *through the task line* instead — the same lever that fixed the three delegation triggers. |
| Restate the ritual steps inside `config.yaml` / the marker | ❌ | Single-source rule (D1): the marker points to AGENTS.md; restating invites drift (identical to the three existing markers). |
| A committed `/xtty:archive` launcher wrapping the skill (thread B) | ❓ deferred | Heavier; the marker→committed-ritual already closes the gap. Build only if the by-effect proof (§7) shows the inline ritual **still** gets skipped. |

## 7. Re-verify by effect — not by syntax

The rule is **un-provable by inspection** — reading back the marker text only confirms the string is present. It is proven only when a **real archive is driven from the marker, autonomously**: on the next archive that a `⟶ archive-ritual` task drives (this change's own tail, or the next open change to archive), on a **fresh/compacted context, without a user prompt**, confirm the apply loop runs the whole ritual — `openspec archive` (spec merge) → finish-by-hand → tracker reconcile → verify-against-disk — from the marker. An **improvised-anyway** result (the loop skips or re-invents the ritual despite the marker) is a **clean failure** that justifies escalating to thread B (the `/xtty:archive` launcher), recorded as a follow-up rather than silently patched. This is the change's held-open primary verify task.

## 8. Reproducible probes

| Probe | Command | Proves | Cannot prove |
| --- | --- | --- | --- |
| Anchor is uncommitted | `git ls-files .claude/skills/openspec-archive-change/` (empty) + `grep -n claude .gitignore` | the archive **skill** is gitignored; only `xtty-*` is tracked | anything about whether the *ritual* ran — that is behavioral (§7) |
| Marker reaches the author | `openspec instructions tasks --change <c> --json` shows the `rules.tasks` seed; `openspec instructions apply … --json` does **not** carry `rules` | the marker must live in the task line to reach apply | that the model *acts* on it (behavioral) |
| Marker present at point-of-tick | `grep -n 'archive-ritual' openspec/changes/*/tasks.md` | every open change carries the marked tail | that the ritual executes (syntax ≠ effect — §7) |
| The measured failure | read `…/archive/2026-07-08-fix-osc7-…/tasks.md` task 4.3 | the failing task had no archive verb / procedure pointer | that a *marked* task would have flipped it green — that is §7 by-effect |

**Known-dead instrument:** a read-back / syntax check of the marker (or `openspec validate`) is **not** a verification of this change — validate only confirms spec/scenario shape, never that the apply loop honored the marker.

## 9. Reusable guideline (G13)

> **The apply loop only reliably executes procedure written at the point-of-tick.** A recurring apply-loop procedure that lives only in AGENTS.md is reconstructed from memory or skipped when the loud, proximate `/opsx:apply` prompt models only *implement*. To make it fire, seed a **per-task marker** at propose (`config.yaml` `rules.tasks`) so it is authored into the task line, and **anchor the marker to committed guidance** — never to a gitignored/tool-generated helper (`git ls-files` the anchor before citing it). Prove it **by effect** (a real run driven from the marker on a fresh context), never by reading the marker text back. Corollary: not every marker is a delegation — a marker may point to an **inline committed procedure** (archive/reconcile) when there is nothing to hand to a subagent.

## Sources

- `openspec/changes/archive/2026-07-08-fix-osc7-hostname-reverse-dns/tasks.md` (task 4.3 — the measured failure).
- `openspec/changes/harden-archive-completion-trigger/{proposal,design}.md` (the fix + decisions D1–D4).
- `.gitignore` (lines 5–14) + `git ls-files .claude/skills/openspec-archive-change/` (the gitignore evidence).
- `AGENTS.md` → "How to work here" (Keep progress current, the three delegation rules) + OpenSpec workflow ("After archiving, finish the merge by hand", Lifecycle rule) + `openspec/config.yaml` `rules.tasks`.
- [`dev-workflow-agent-orchestration.md`](dev-workflow-agent-orchestration.md) (point-of-tick marker prior art) · [`claude-code-subagent-execution-forensics.md`](claude-code-subagent-execution-forensics.md) (affordance-not-disobedience framing).
</content>
</invoke>
