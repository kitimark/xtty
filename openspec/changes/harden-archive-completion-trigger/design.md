# Design — harden-archive-completion-trigger

## Context

The apply loop (`/opsx:apply`, a generic skill we do not own) walks `tasks.md` and models only *implement* tasks. Any procedure that lives only in AGENTS.md — loaded at session start, distant from the point of action — is reconstructed from memory or skipped. The project already learned this for agent delegation and solved it with a **point-of-tick marker** (`⟶ xtty-test-validator`, etc.) seeded via `config.yaml` `rules.tasks`. The archive + reconcile ritual is the same class of problem, unscaffolded. This change adds the missing marker, choosing its anchor carefully because the obvious anchor (the `/openspec-archive-change` skill) is gitignored.

## Goals / Non-goals

- **Goal:** a change's completion reliably drives the full archive + reconcile ritual from a signal that reaches the apply loop, with a **committed** procedure anchor.
- **Goal:** future proposals emit the marker automatically; the four open changes are retrofitted so it is live now.
- **Non-goal:** a new archive *agent* — archive is a checklist, not a context-flooding delegation, and AGENTS.md's "don't pre-build tooling" refutation applies.
- **Non-goal:** editing the generic `/opsx:*` skills, or forcing the machine-local skill on contributors who do not have it.

## Decisions

### D1 — The marker points to the committed ritual, not the gitignored skill

`⟶ archive-ritual` resolves to the **committed** procedure: AGENTS.md → OpenSpec workflow **"After archiving, finish the merge by hand"** + **"Keep progress current"** + the `openspec archive` CLI. The `/openspec-archive-change` skill is openspec-generated and gitignored (confirmed: `git ls-files` empty; `.gitignore` tracks only `.claude/…/xtty-*`; the `research-capture` spec Purpose already classifies the openspec-generated commands/skills as ignored). Baking `⟶ /openspec-archive-change` into a committed `tasks.md` would be a committed reference to an uncommitted tool — fragile across clones/CI/contributors, and the coherence critic would flag it as drift. The skill stays an **optional local accelerator** (it adds a task-completion gate + a sync-diff preview) a contributor may run when present; the *anchor* is committed.

### D2 — A "procedure marker", not an agent-delegation marker

The existing three markers delegate to a committed `xtty-*` agent (they move work *out* of the session to absorb noise). `⟶ archive-ritual` is different: it points to an **inline committed procedure** run in-session. This is a deliberate, minor semantic departure — archive/reconcile is a short deterministic checklist that produces the very tracker edits the session must own, so there is nothing to delegate. The marker's job is purely *affordance at the point of action*, not context isolation.

### D3 — The standard change tail

Every change ends the same way, so the shape is recognizable and the critic can check it:

```
  ┌─ … build + verify tasks … ─┐
  │                            │
  ▼                            ▼
 [ pre-archive coherence ]  ⟶ xtty-openspec-critic (<change>)
 [ archive + reconcile   ]  ⟶ archive-ritual
        │
        ├─ openspec validate → openspec archive (merge spec deltas + move)
        ├─ finish-by-hand: new-spec Purpose, correct merged text, validate --all --type spec
        ├─ reconcile: AGENTS row+snapshot, HISTORY narrative, milestones, Learned-refutations
        └─ verify-against-disk: openspec list / ls changes/archive / ls specs
```

Two of the four open changes already carry the coherence half (their `⟶ xtty-openspec-critic` task); only the archive half is missing. The retrofit adds the second task; it does not duplicate the first.

### D4 — Verify by effect, hold-open

The rule is un-provable by inspection (a syntax check just confirms the marker text). It is proven only when a real archive is driven **from the marker**, autonomously. This change's own final task carries `⟶ archive-ritual`, so archiving it is the by-effect test: the apply loop must run the whole ritual from the marker without a user prompt, on a fresh/compacted context. Sequencing is load-bearing — apply this change first (its retrofit marks the other four), then the next change to archive exercises the marker.

## Risks / Trade-offs

- **The marker text drifts from the ritual.** Mitigated by D1's single-source rule (the marker points to AGENTS.md; `config.yaml` and the marker never restate the steps) — identical to the three existing markers.
- **Contributors without the skill.** Handled by D1: the committed CLI ritual is always available; the skill is optional.
- **Semantic overload of "⟶".** D2 documents that one marker (archive-ritual) is a procedure pointer, not an agent — noted in AGENTS.md so the critic does not expect an agent for it.
- **Over-tooling.** Thread B (a `/xtty:archive` launcher) is deferred behind the by-effect gate — build it only if the inline ritual is still skipped after the marker lands (the delegation-trigger's "an inline-anyway result justifies a stronger gate" pattern).

## Migration Plan

Docs/workflow only — no product code, no build impact. Apply order: AGENTS.md + `config.yaml` (the rule) → retrofit the four open changes → `research-capture` spec delta → research doc → hold open for the by-effect proof at the next archive. Independently mergeable; no dependency on the other open changes beyond retrofitting their task lists.

## Open Questions

- Does the by-effect proof pass on the first marked archive, or does the inline ritual still get skipped (→ escalate to thread B)? Resolved at the hold-open archive.
