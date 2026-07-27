# Proposal: slim-status-surface

## Why

`slim-agents-context` (archived 2026-07-06) cut AGENTS.md from 80.6 KB to 28.1 KB and measured the result: **−21,548 startup tokens**, behavioral pass rate **34/36 → 36/36** (`openspec/changes/archive/2026-07-06-slim-agents-context/probes/results.md`). Twenty-two days later the file is back to **44,996 B**, and the regrowth is concentrated in exactly one section: `## Current status` is **22,613 B — 50.3% of the whole guide**, of which the **`Learned refutations` list alone is 17,367 B (38.6% of the file)** across 31 entries averaging ~88 words. That list shipped as **11 one-liners costing ~463 tokens total** (`probes/results.md` V3 arm).

The regrowth is not the rule failing — it is the rule's *shape* being under-specified. `research-capture`'s ratified bound (`openspec/specs/research-capture/spec.md:48`) requires "**inline one-line statements** of learned refutations"; 20 of 31 current entries exceed one line, so the list is already out of conformance. Three further defects compound it:

1. **Duplication after retirement.** Ten entries (~7.2 KB, 41.5% of the list) restate the same cross-model-review / guide-gate saga; `remove-cross-model-review` *appended* a retirement entry rather than editing the entry it retired (`AGENTS.md:60` ⊃ `:69`, near-verbatim — 805 B recoverable at zero information loss). No rule forbids that append today.
2. **A cached measurement that silently went wrong.** The guide transcribes the measured test envelope, and the cached copy is **currently false**: AGENTS.md, HISTORY.md, and `packer/README.md:667` all assert "the prior 56-test envelope was identical across all 5 environments", but `packer/README.md:644–648` records that the change adding the 56th test never ran the VM tiers — the last 5-environment-identical measurement is the **55**-test `54/0/1` (2026-07-10), so the VM tiers are 3 tests behind across 2 changes. Three copies drifted together into one wrong claim; the duplication detected nothing. Worse, the nominal home is itself unusable as a pointer target: `packer/README.md`'s `### Acceptance` section *leads* with a figure six supersessions stale (`Envelope: 40/1/1 of 42`, `:299`) while the current figures sit in a blockquote 350 lines down, and the only string reading "current authoritative envelope" (`:603`) points at a superseded figure.
3. **A perpetual row that became a mini-index.** The shipped table's `Tooling` row is **1,773 B — 58% of the 3,074 B table** — an accreted per-change list, which the ratified category-keyed bound (`research-capture:48`) already forbids.

Costs compound per spawn: subagent inheritance of the full guide is measured-confirmed (`probes/evidence/subagent-inheritance-probe.md`), so every agent in this repo's routine multi-agent workflows pays the full file.

## What Changes

- **Compress the 31 refutations to 24 bounded entries** (17,367 B → ~8.8 KB, −50%): 11 already-compliant one-liners kept **byte-for-byte** (including the ablation-anchored retry-ban entry, which is frozen); 10 compressed to conclusion + applicability condition + verified evidence pointer; the 10-entry cross-model/guide-gate cluster merged into **3** entries. Every dropped clause is re-verified as homed in `research/` or `HISTORY.md` before removal. **Nothing is deleted from the repository** — only from the always-loaded surface.
- **Rehome one orphaned fact first.** The `CGEvent` `wheel1` sign-inverse note exists *only* in AGENTS.md prose; it moves into the existing sign-convention comment at `AppUITests/XttyMouseWheelUITests.swift:26–32` (comment-only) before its entry is compressed.
- **Give `packer/README.md` → Acceptance a single current-truth block** — a per-(tier, golden) **Current envelope** table with a `CURRENT | STALE (n behind) | SUPERSEDED` status token, above an append-only `Envelope history` log, plus anti-reaccretion maintenance rules. **This lands first, in its own commit**, and it corrects the confirmed-false "56-test envelope identical across all 5 environments" claim in AGENTS.md / HISTORY.md / packer.
- **Replace the snapshot's cached test counts with a pointer** to the new Current-envelope block (the single current truth; `test-validation:28` already names the test-image documentation as the living envelope's home).
- **Keep the open-changes table and the snapshot.** The open-changes table (298 B) stays a table — it is spec-required ("a tabular per-change entry"), it is 1.3% of the section, and keeping it means the entire restructured section is compliant under the current ratified spec text with no table-related delta. The five closed product-phase rows of the shipped table also stay; only the `Tooling` row's mini-index collapses to a category-keyed summary + pointer (already required by the ratified bound — no delta needed for that either).
- **Amend the spec with three anti-regrowth ratchet clauses** so the regrowth cannot recur: a learned-refutation entry is bounded to one sentence + applicability condition + evidence pointer; retiring/superseding the mechanism a refutation was measured on **edits the existing entry in place**, never appends a second entry; and the measured test envelope is pointed to, not cached — with the pointed-to home required to state its current answer plainly and up front.
- **Update the coupled tooling in the same commit as the guide edit**: `.claude/skills/xtty-capture-research/SKILL.md`, `.claude/commands/xtty/capture-research.md`, `.claude/agents/xtty-openspec-critic.md` (refutation-bound + edit-in-place + cached-envelope checks; definition stamp v7 → v8 at all three coupled sites), and AGENTS.md's *Keep progress current* rule (tracker clause only).
- **Verify by effect against a pre-registered envelope**, reusing the archived `slim-agents-context` probe harness with a freshly frozen baseline: ≥3,000-token floor, zero trap regressions, a turn-1 inline-sufficiency criterion on the merged cross-model cluster, and a bounded 2-iteration fix loop.

## What Does NOT Change

- **The full status-surface shape survives**: snapshot, open-changes table, closed-work rows, established-specs derive-on-demand line, and inline refutation conclusions all remain. This is a compression, not the "move refutations behind a pointer" shape, which two specs forbid (`research-capture:86` "not as bare pointers"; `agent-guide-parity:9` "exactly one canonical guide").
- **No `/xtty:status` command, agent, skill, or `make status` target.** Refuted by the repo's own don't-pre-build-a-speculative-roster finding; deferred until friction is observed.
- **No product code** (one test-file *comment* excepted), no build system, no CI, no test behavior, no `openspec/config.yaml` edit (verified: its 4 `rules.tasks` entries are marker rules only), no `.claude/agents/xtty-test-validator.md` edit and no `test-validation` delta (the validator reads the whole `packer/README.md`; the `### Acceptance` heading survives and the envelope stays adjacent to the expected-difference matrix).
- **CLAUDE.md** is a symlink — parity propagates for free.

## Capabilities

### New Capabilities

*(none)*

### Modified Capabilities

- `research-capture`: the tracker-reconcile step's leanness bound gains three ratchet clauses — a learned-refutation entry is **bounded to one sentence + applicability condition + evidence pointer** (mechanism/chronology live behind the pointer); when the mechanism a refutation was measured on is retired or superseded, the reconcile step **edits the existing entry in place** rather than appending a second entry about the same finding; and the **measured test envelope is pointed to, not cached** in the guide, with the pointed-to home required to state its current answer plainly and up front.

## Impact

- **Files (10 + change dir):**
  - `AGENTS.md` — `## Current status` (L9–69) replaced: 22,613 B → 12,338 B measured on the draft (−10,275 B, ≈4.2k startup tokens at the measured 2.46 B/token); the *Keep progress current* rule (L127) amended, tracker clause only.
  - `packer/README.md` — `### Acceptance` gains the Current-envelope block + append-only history log; the Expected-difference matrix loses its two illegal counts (`:683`, `:688`, violating its own `:675–676` no-numbers rule); the reverse-duty paragraph (`:690–712`, three envelope generations stale) collapses to the rule alone; the false 5-environment claim corrected.
  - `AppUITests/XttyMouseWheelUITests.swift` — comment-only (`wheel1` sign-inverse rehome).
  - `HISTORY.md` — dated narrative entry + the 5-environment-claim correction at `HISTORY.md:64`; receives any mechanism detail displaced by compression that lacks another home.
  - `.claude/skills/xtty-capture-research/SKILL.md` — refutation-bound + edit-in-place + envelope-pointer edits; `version 1.2 → 1.3`.
  - `.claude/commands/xtty/capture-research.md` — line 10 (it restates the reconcile triad).
  - `.claude/agents/xtty-openspec-critic.md` — Pass-1 category-keyed bullet extended to the refutations list (one-sentence bound + edit-in-place); Pass-2 gains a cached-envelope check (a re-introduced envelope figure in the guide is a BLOCKER); definition stamp v7 → v8 at all three coupled sites (L9, L59, L62).
  - `research/03-analysis/agents-md-context-budget.md` — dated addendum (regrowth curve, probe results) + `research/README.md` index touch.
  - `research/04-design/02-milestones.md` — tracker touch.
  - `openspec/specs/research-capture/spec.md` — via the delta at archive.
- **Every future session and every subagent spawn:** ~10.3 KB / ≈4.2k tokens freed, ×N agents per workflow (inheritance measured-confirmed).
- **Risk surface:** a compressed refutation could stop inoculating (the archived V3 arm regressed the retries trap to 0/2 when the list was removed). Gated by trap probes with a turn-1 zero-file-read sufficiency criterion on the most-compressed cluster; any failure is repaired by restoring that one line's conclusion clause (2-iteration cap), never by restoring narrative.
- **Interaction with open changes:** `add-ci-pipeline` is the sole open change and is owner-blocked; if it archives mid-flight its row is simply removed from the kept table per the normal reconcile. No structural conflict.
