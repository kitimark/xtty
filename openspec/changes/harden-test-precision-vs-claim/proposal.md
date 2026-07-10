## Why

While implementing `fix-scroll-reversal-redraw-corruption`'s regression test, a real full-screen-program end-to-end approach was drafted first (mirroring an existing test) and would have shipped a test that passes green while proving nothing: the bundled programs available for a real end-to-end test (`vim`, `less`) never invoke the buggy `cmdScrollDown` path at all, regardless of how they're driven, because a program's own escape-sequence idiom choice is outside this project's control. This was caught before shipping, but only by the person authoring the test happening to investigate deeply — nothing in the project's coherence-review checklist would have caught a change that shipped the wrong-depth test with high confidence. This durably captures the lesson: a test's precision must match the specific claim it exists to prove, and this project's own review tooling should be able to ask that question.

## What Changes

- Add a new rule to `AGENTS.md`'s "Keeping a change coherent" walk-list: when a change adds or modifies a regression test, `design.md`'s Decisions (or Risks/Trade-offs) must name the specific claim the test proves, the layer/mechanism that claim lives in, and why the chosen driver (real program or synthetic/direct) actually reaches that layer — framed symmetrically (an over-deep test is as wrong as a too-shallow one; a real end-to-end program is the *right* tool for a claim that lives upstream of program-specific behavior, and the *wrong* tool for a claim about one narrow internal code path a given program may or may not exercise).
- Extend the `xtty-openspec-critic` agent's single-change coherence pass with one new heuristic check (REVIEW-level, alongside the existing mechanism-neutrality and design↔requirements-traceability heuristics — a semantic prose judgment, not a mechanical gate) operationalizing the new rule, and bump the agent's `Definition version` stamp.
- No product code changes.

## Capabilities

### New Capabilities

<!-- none — this hardens an existing review capability's checklist -->

### Modified Capabilities

- `coherence-review`: the **Committed coherence-review agent tooling** requirement's single-change pass gains one more heuristic check — whether a change that adds/modifies a test states its target claim, layer, and driver-reach in `design.md`.

## Impact

- **`AGENTS.md`**: one new bullet in "Keeping a change coherent" (the authoritative rule text).
- **`.claude/agents/xtty-openspec-critic.md`**: one new Pass-1 checklist line + a bumped `Definition version` stamp.
- **No** product code, no `openspec/config.yaml` change (a delegation-marker-style entry was considered and rejected — see design.md), no new template section.
