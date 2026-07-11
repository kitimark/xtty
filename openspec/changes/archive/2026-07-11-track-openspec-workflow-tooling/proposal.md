## Why

The OpenSpec workflow tooling that the `openspec` CLI generates into `.claude/` — the `commands/opsx/*` launchers and the `skills/openspec-*/` skills — is currently gitignored. That leaves the spec-driven workflow **not self-contained**: a fresh clone has no `/opsx:*` commands or `openspec-*` skills until someone runs the CLI's generation step, the exact prompt text each agent runs is **unpinned** (a silent `openspec` version bump can change how `/opsx:apply`, `/opsx:archive`, etc. behave with no diff), and changes to that tooling are **invisible to review**. The project already version-controls its own `xtty-*` tooling in the same tree; leaving the generated half ignored makes the `.claude/` workflow surface an inconsistent mix.

## What Changes

- **Un-ignore (targeted)** the two generated tooling trees so they become git-tracked, mirroring the existing `xtty-*` re-includes: add `!.claude/commands/opsx/` and `!.claude/skills/openspec-*/` to `.gitignore` and rewrite the leading comment that currently states these "stay out of git."
  - `.claude/settings.local.json` and `.claude/scheduled_tasks.lock` **remain ignored** (machine-local) — still caught by the `.claude/*` rule.
- **Record the tracking-and-pinning policy** as build-workflow truth: the generated workflow tooling is committed and pinned to a recorded CLI version (anchor: the `generatedBy: "1.4.1"` stamp each file carries), with a drift policy — regenerate via `openspec init`/`update` and **re-commit deliberately** on a CLI bump. This is the intentional mirror-image of the existing rule that the generated Xcode project is *untracked*; the two generated-artifact classes are treated oppositely on purpose (see design).
- **Reconcile AGENTS.md** to the new policy:
  - The Conventions "Don't track local tooling" bullet — add `opsx`/`openspec-*` to the committed set and state the drift policy.
  - **Knock-on:** three passages currently justify the `⟶ archive-ritual` marker by calling `/openspec-archive-change` "gitignored"/"uncommitted" (the G13 Learned-refutation, the *Keep progress current* archive-ritual passage, the tasks.md archive-marker rule). Committing the skills makes that literally false, so reframe them to preserve the underlying principle — anchor the archive ritual to the **hand-authored committed AGENTS.md procedure**, not to the **CLI-generated** skill (which `init`/`update` can rewrite even once committed).

Non-goals: no change to `settings.local.json`/lock handling; no blanket "track all of `.claude/`" default; no change to any app runtime behavior; no change to how the `openspec` CLI is invoked in the workflow.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `build-workflow`: ADD a requirement that the generated OpenSpec workflow tooling under `.claude/` is tracked in version control and pinned to a recorded CLI version (the deliberate counterpart to the existing "Generated Xcode project ... SHALL NOT be tracked" requirement). Mechanism-neutral: the *what* (tracked + pinned + a re-commit-on-bump drift discipline) lives in the spec; the *which paths / `!`-re-includes / why the two artifact classes differ* lives in design.

## Impact

- **`.gitignore`** — two `!`-re-include lines added; leading comment rewritten.
- **Newly tracked files** — `.claude/commands/opsx/*.md` (8) and `.claude/skills/openspec-*/SKILL.md` (8) enter version control.
- **`AGENTS.md`** — Conventions "Don't track local tooling" bullet + three archive-ritual passages reconciled.
- **`openspec/specs/build-workflow/spec.md`** — one added requirement (merged at archive).
- **No code, no APIs, no app runtime surface** affected — this is a meta/tooling + documentation change only.
