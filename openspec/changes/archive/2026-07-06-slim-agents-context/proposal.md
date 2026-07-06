# Proposal: slim-agents-context

## Why

AGENTS.md — loaded into every session via the CLAUDE.md import — has grown from 12 KB to 80.6 KB in 8 days (~8.5 KB/day) and now costs **32.8k tokens at every session start** (measured via `/context`; the file's backtick-dense style tokenizes at 2.46 bytes/token). That is the single largest line item in the startup budget — larger than the system prompt plus all built-in tool schemas combined — and ~19k tokens of it is per-change *history* that already lives in `openspec/specs/` (what is true), `openspec/changes/archive/` (full proposal/design/tasks), and `research/` (the mechanisms and why). Beyond cost, burying the ~5k tokens of durable rules inside 33k of narrative is the "lost in the middle" failure mode: it dilutes rule adherence rather than helping it. The growth is structural — the "Keep progress current" rule as practiced appends a saga per change — so without a format change the file re-inflates at ~2.5k tokens/day.

## What Changes

- **Split AGENTS.md into rules (kept) and history (moved).** Create a root `HISTORY.md` — *not* imported by CLAUDE.md, read on demand — and move the three history blobs into it **verbatim** (nothing deleted, nothing rewritten): the ✅ per-change narratives in *Current status*, the ~33 KB changelog tail embedded in the *OpenSpec workflow* section, and the CI-run history digest in *Building*.
- **Rewrite *Current status* as a snapshot + table.** One short snapshot paragraph (milestone position, test counts, acceptance envelope) plus a table — `change | state | one-liner | detail pointer` — so orientation and routing survive at ~5% of the token cost.
- **Keep the scar tissue inline.** ~10 one-line inoculations for expensively-learned refutations (retry tolerance masks races; `run_in_background` strands subagents; menu re-assert is a no-op; `hasForegroundJob` waits refuted; …) stay in AGENTS.md with the conclusion stated, not just pointed to — moving history must not lose the lessons.
- **Trim *Building*** to the quick-start table + prerequisites; the CI saga becomes a few sentences + a pointer to `research/03-analysis/github-actions-ci-cd.md`.
- **Amend the "Keep progress current" convention** (the fix that makes it stick): on change completion, the AGENTS.md edit is a bounded one-line table update; the narrative is appended to `HISTORY.md`. The `xtty-capture-research` skill checklist is updated to match (deference chain preserved — rules live only in AGENTS.md).
- **Verify by effect against a pre-registered envelope** (repo-style): ≥20k input tokens saved at session start measured from headless-run usage stats, and a fat-vs-slim behavioral probe suite (rule-compliance / recall-routing / refuted-decision traps) with zero regressions tolerated on the rule and trap classes.
- **Measure by ablation, not just A/B:** two diagnostic variants alongside fat and slim (slim-minus-table, slim-minus-inoculations) produce a dose-response table proving what each retained tier costs and earns; a per-variant **context-usage probe harness** (headless first-turn usage, cross-checked against `/context`) supplies the token numbers; and a **subagent-inheritance probe** settles whether Task-tool subagents also carry AGENTS.md — if they do, every 7–24-agent workflow this repo runs multiplies the savings (~615k tokens per 24-agent workflow), measured before claimed.
- **Capture the investigation** as a research doc (`research/03-analysis/` — the growth curve, token-density measurement, `/context` budget breakdown, probe results) per the capture-depth bar.

## Capabilities

### New Capabilities

*(none)*

### Modified Capabilities

- `research-capture`: the documented capture-and-reconcile workflow's tracker-reconcile step changes shape — the always-loaded guide (AGENTS.md) SHALL stay lean (bounded per-change status entries in a snapshot + table format), with full per-change narratives recorded in a history log that is not loaded at session start; reconcile targets gain the history log.

## Impact

- **Files:** `AGENTS.md` (restructured; ~80 KB → ~18 KB), `HISTORY.md` (new, receives moved text verbatim), `.claude/skills/xtty-capture-research/` (checklist updated to the new reconcile format), `research/03-analysis/` + `research/README.md` (new capture), `openspec/specs/research-capture/spec.md` (via delta at archive).
- **No product code, no build system, no tests** — docs and committed tooling only. CLAUDE.md's import mechanism is unchanged (AGENTS.md remains the canonical guide; it just stops carrying the archive).
- **Every future session** in this repo: ~25k tokens freed at startup; post-compaction summaries lean on a denser, rules-first file. If the subagent-inheritance probe confirms Task-tool subagents carry the file too, the savings multiply by every agent of every workflow (this repo routinely runs 7–24-agent workflows) — the probe decides whether that claim ships.
- **Risk surface:** sessions that previously answered history questions from context must now follow a pointer (`Read` on demand) — the probe suite exists to prove the trap class (silently re-proposing refuted decisions) does not regress; any trap failure is repaired at pointer granularity (strengthen the one-liner), never by restoring the bloat.
- **Interaction with open changes:** none structural — but the apply should land *before* long apply sessions (e.g. `retire-metal-renderer`, 24 tasks) to pay out, and any change archived while this one is in flight just means its status entry is written in the new format.
