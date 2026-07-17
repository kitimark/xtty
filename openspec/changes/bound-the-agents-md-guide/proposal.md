## Why

`AGENTS.md` is auto-injected into **every session and every subagent**. It has been deliberately dieted **twice** and regrew to ~80 KB **both times** — the second time in **48 hours** (28,100 B → 80,107 B in 5 days; 43,667 B → 81,012 B in 2 days). A 2026-07-10 study predicted the second regrowth **in writing** and was ignored the next day.

The obvious diagnosis is wrong. **The leanness rule is not missing — it is overridden.** It exists at three surfaces, all predating both regrowths: a **SHALL** in `openspec/specs/research-capture/spec.md` ("Reconciling a completed change SHALL NOT grow the guide's status surface beyond a bounded entry"), a point-of-action instruction in `.claude/skills/xtty-capture-research/SKILL.md` ("Narrative paragraphs never go here"), and a category-keyed bound in `.claude/agents/xtty-openspec-critic.md`. The rule reached the loop at **spec grade**, at the **point of action**, and at **review time** — and was overridden every time. **100% of the +37,345 B was *instructed* writing** (archive/capture/reconcile commits); there were zero rogue appends.

> **The disease is not REACH. It is ADMISSION.** The write rule *orders* the append; nothing controls admission to the eagerly-injected tier. And a guard scoped to one surface merely **displaces** growth: the critic's guard held its row (1,934 B today) *while the file doubled*, because the mandated narrative moved to an unguarded tier.

So the fix must sit **below the agent**, where no instruction, tool choice, or wrapper can route around it.

## What Changes

- **Land the guide-gate: a tracked `.githooks/pre-push` hook**, installed per-clone into the repository's own git dir by a `make hooks` target. It refuses a push that **grows the eagerly-injected guide past a ceiling**, measured on the **committed blob** of the **pushed tree**. Its only bypass is `--no-verify` (an explicit forbidden act — the R3 residual the repo already accepts).
- **The meter measures what is actually injected**, not one file: it resolves the eager-root set (`CLAUDE.md`, `.claude/CLAUDE.md`, `CLAUDE.local.md`, and unscoped `.claude/rules/**`), follows `@`-imports transitively, and weighs **bytes via git** — so a symlink, a mode-swap, a moved import, or a "fake diet" into `.claude/rules/` cannot route around it.
- **The comparator is GROWTH-vs-BASELINE, not absolute-ceiling-while-over** — a shrinking or unchanged push always passes, so the diet is always permitted and unrelated work is never frozen.
- **The ceiling is a measured RATCHET, never an aspirational number.** Its first notch is set from the **achieved** size, and it may only decrease.
- **A `hooks` install target** wired as an unconditional, cannot-fail, order-only prerequisite of the routine `make` entry points — because nothing routine re-triggers bootstrap, so a hook installed only at `setup` would leave the maintainer's own machine (which produces essentially every push) **unarmed**.
- **A CI installer-regression check** asserting the installed hook is byte-identical to the tracked source. *(It verifies CI's own clone — it is **not** a detector of unarmed dev clones. Naming this honestly is part of the change.)*
- **Admission control on refusal: PARK the finding, never lose it.** A refused append is routed to its named tracked (lazily-loaded) surface, not dropped.
- **The diet itself is already landed, twice.** `e50cc2b` (2026-07-13): 81,012 → 64,079 B, −20.9%, nothing deleted — the two offender refutation entries compressed to the shape the other 23 already had, and the cross-model procedure relocated to a pointer. A further diet (2026-07-17, via a `/doctor` derivability pass, currently an uncommitted working-tree edit): the remaining cross-model/gate refutation cluster compressed further, the coherence-checklist walk-list relocated to `research/03-analysis/openspec-coherence-checklist.md`, the fully `ls`-derivable "Repository structure" tree cut, and the Building command table compressed to only what `make`'s own self-documentation doesn't already say — landing at **51,252 B**. This change makes the diet **stick**, whatever its size is when applied — see design D6's apply-time measurement rule (a hardcoded ceiling in this document already went stale twice before this change was even applied).

## Capabilities

### New Capabilities
- `agent-guide-budget`: the eagerly-injected agent guide is **bounded and mechanically enforced** — the eager-root set and its import closure, the byte meter, the growth-vs-baseline comparator, the ratcheting ceiling, the fail-closed pre-push gate, and the park-don't-lose refusal protocol.

### Modified Capabilities
- `build-workflow`: a new `hooks` entry point that arms the clone, wired as an order-only prerequisite of the routine entry points, plus the CI installer-regression check.
- `research-capture`: the tracker-reconcile step's existing leanness SHALL gains a **mechanical backstop** and a **refusal protocol** — when an append is refused, the finding is parked on a named tracked surface rather than dropped.

## Impact

- **New:** `.githooks/pre-push` (tracked source of truth), `scripts/install-hooks.sh`, `Makefile` `hooks` target, a CI step, and a committed fixture suite + mutation matrix (currently prototyped at `research/artifacts/guide-gate/` — **45 isolated fixtures, 45/45 green, every fix mutation-proven**).
- **Modified:** `Makefile` (order-only `hooks` prerequisite on `build`/`test`/`test-core`/`run`/`install`/`setup`), `.github/workflows/ci.yml`, `AGENTS.md` (the bound + the park protocol).
- **Not changed:** any product code. This is repository-workflow tooling.
- **Known residual (accepted in writing):** a **docs-only clone that never runs `make`** is never armed. Nothing can force it; it is routed to the CI detector lane.
- **Prior art / evidence:** `research/03-analysis/agents-md-structural-best-practices.md` (the 14-round investigation), `research/artifacts/guide-gate/` (the working prototype, its fixtures, and its mutation matrix), and guidelines **G-TARPIT-6/7** in `cross-model-review-tar-pit-forensics.md`.
