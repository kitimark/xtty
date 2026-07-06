# Subagent-inheritance probe (task 1.4, design D8) — 2026-07-06

**Question:** do Agent-tool (Task) subagents inherit CLAUDE.md/AGENTS.md into their context?

**Method:** fresh `general-purpose` subagent spawned from the apply session (fat checkout, AGENTS.md @ `a9b3a47`),
instructed to answer WITHOUT tools: quote the complete line of its context containing the marker string
`probe-quoted verbatim`. Marker uniqueness pre-verified: exactly 1 occurrence in AGENTS.md; 0 in CLAUDE.md,
0 in the memory directory, 0 elsewhere in session-loadable context. (The copy in the change's probes/README.md
is not session-injected.)

**Result: CONFIRMED — subagents inherit AGENTS.md.**

- The subagent quoted the marker line **verbatim** (the "Editing the agent file itself is different…
  measured 2026-07-06: a spawn 63 s after an edit was served the stale pre-edit copy — probe-quoted
  verbatim — …" sentence) and correctly located it: "project instructions — specifically in the contents
  of `/Users/markmark/source/contribute/xtty/AGENTS.md` (imported via CLAUDE.md), in the **How to work
  here** section".
- Harness-reported usage for this trivial, zero-tool task: **subagent_tokens = 49,306; tool_uses = 0;
  duration 16.0 s**. Zero tool uses = the quote came from injected context, not a file read.

**Implication (the multiplier):** every Task-tool subagent spawn pays the AGENTS.md cost. At fat
(~32.8k tokens/copy), this repo's routine multi-agent workflows cost ~230k (7-agent) to ~790k (24-agent)
tokens in AGENTS.md copies alone; at the slim target (~7k) the same workflows pay ~49k–170k. The
restructure therefore saves ~25k × N-agents per workflow, an order of magnitude beyond the per-session
saving.

**Cross-check available to any future reader:** re-run the same probe with any unique AGENTS.md string;
or compare `subagent_tokens` of a trivial no-tool spawn before/after the restructure (expect ≈ −25k).
