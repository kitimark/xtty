# Design — add-test-validation-agent

## Context

The validation workflow was executed by hand, end-to-end, in the `fix-main-menu-clobber` session: `make test-core` → local `make test` → host `build-for-testing` → fresh clone of the bash `xtty-test` golden → headless `test-without-building` ×2 → graphics run → per-red classification → evidence bundle + REVIEW.md. Every guardrail below was learned there (or in the sessions before it) and is evidence-backed. The agent codifies the *procedure and discipline*; the *numbers* (acceptance envelope, expected differences) stay in the repo and are read at runtime.

Claude Code custom agents are markdown files under `.claude/agents/` (frontmatter: name/description/tools; body = system prompt), invoked explicitly by name or auto-selected by description match. `.claude/` is gitignored except the committed `xtty` tooling — the exception pattern extends to agents.

## Goals / Non-Goals

**Goals:**
- One committed agent that runs any subset of the four tiers and returns the fixed-skeleton verdict report.
- Main-context reduction: the polling/SSH/log noise stays inside the agent; the session gets ~2k tokens.
- Two spawn paths: direct user request (`/xtty:validate` launcher) and OpenSpec verify-task delegation (AGENTS.md rule + description auto-match).
- Staleness-proof: envelope + matrix read from `packer/README.md` at runtime; the matrix gets its durable home there as part of this change.
- The failure-classification discipline (bucket-or-stop) encoded, not just the commands.

**Non-Goals:**
- No product/test/CI code changes; the agent only *runs* what exists.
- No auto-cleanup (owner decision: the agent reports a cleanup manifest; rigs are kept for follow-on review).
- No CI-inspect mode yet (noted as the natural v2: CI is a fifth column of the same consistency matrix).
- No parallel VM execution (deliberately serialized — see D6).
- Not a general-purpose test framework: this is xtty-rig-specific tooling.

## Decisions

**D1 — An agent, not a skill (unlike `research-capture`).**
The capture-research workflow is a *checklist the main loop follows* (cheap, doc-editing). Validation is *tool-execution-heavy* (30+ min of polling and logs) — the value is context isolation, which only a subagent gives. The launcher command mirrors the existing pattern so the user ergonomics stay uniform. Alternative (skill in main loop) is what we do today; it measurably floods the session.

**D2 — Numbers live in the repo; the agent reads them at runtime.**
The acceptance envelope (`packer/README.md` → Acceptance) shifts with `retire-metal-renderer` (41-test suite), `harden-churn-shell-readiness` (local flake), and the harness-truthing successor (paste test). Hardcoding any count in the agent prompt rots in weeks. The agent's prompt carries the *procedure*; `packer/README.md` carries the envelope **and** (new, this change) the **expected-difference matrix**. Same deference-chain principle as the capture-research skill deferring to AGENTS.md. The chain carries a **reverse duty**, documented in AGENTS.md: any change that alters test counts or expected residuals updates `packer/README.md`'s Acceptance/matrix in the same session — otherwise "runtime read" just relocates the staleness.

**D3 — Fixed report skeleton (the Scenario-B contract).**
The apply loop must act on the report, so its shape is stable: `VERDICT (IN-ENVELOPE | OUT-OF-ENVELOPE | REGRESSION)` → per-tier verbatim counts + failing sets → per-red classification (named bucket vs **UNEXPLAINED** — any UNEXPLAINED forces verdict ≠ IN-ENVELOPE) → cross-tier consistency vs the matrix → evidence paths (bundle + REVIEW.md, written by the agent to `~/Downloads/xtty-vm-poc/artifacts/<run-name>/`) → feedback (what the caller should do next) → **cleanup manifest** (everything created/left running, with the exact commands to remove it; nothing deleted by the agent).

**D4 — Two spawn scenarios, wired by AGENTS.md rule + description match.**
(a) User: `/xtty:validate [tiers]` or plain natural language. (b) OpenSpec: an AGENTS.md rule — *verify tasks that execute the test suite are delegated to `xtty-test-validator`; the main loop consumes only its report and records verbatim results in the task tick*. The agent's frontmatter `description` states the same trigger so auto-selection works without the rule being quoted. A per-task `(delegate: …)` marker convention was considered and rejected for authoring burden; revisit only if delegation drift appears.

**D5 — Tier model + defaults.**
Tier 0 `make test-core` (~1 min) · Tier 1 local `make test` (~5 min; warn the user hands-off — mouse interference is a measured flake source) · Tier 2 headless VM (~7 min/run; the race-sensitive CI-parity environment) · Tier 3 graphics VM (~7 min; watchable; post-menu-fix it must equal headless). Defaults: **core + local + headless×1**; **full sweep** (core + local + headless×2 + graphics) for product-code changes — per-launch races need ≥2 VM runs (Tart run-1 masking precedent). Callers can request any subset.

**D6 — Serialize VM runs.**
Tier 2's value is the 3-vCPU race-timing environment; two concurrent clones on one host contend and muddy exactly that timing. Runs execute sequentially even when ×2 is requested.

**D7 — VM mechanics live in `packer/README.md`; this change makes that section true first.**
The README's Runtime workflow today documents an **in-guest build** that cannot run on the Metal-free golden until `retire-metal-renderer` lands (verified: no open change owns correcting that text), while the proven recipe exists only in session transcripts — so "defer to the README" would today defer the agent into a doomed build. Task 1.3 therefore corrects the section to the interim recipe *before the agent exists*: `tart clone` + `tart set --cpu 3 --memory 7168 --display 1024x768`, headless via `--no-graphics`, SSH key `~/.ssh/xtty-vm` injected via `tart exec` on fresh clones, host `xcodebuild build-for-testing` → rsync `Products/` + the `__TESTROOT__`-relative xctestrun (superseding §8b's shared-`/tmp` variant) → guest `xcodebuild test-without-building`, **no retry flag** — marked *interim until `retire-metal-renderer` is applied to the repo under test*, with the flip back to in-guest builds pre-registered to that change / `add-xtty-test-image`. The agent prompt defers to the README for the commands and carries only the discipline, plus two agent-side specifics: probe `TART_HOME` before cloning (the golden may live on an alternate volume), and one **precedence rule** — the agent never executes the workflow's final `tart delete` step; clone removal goes into the cleanup manifest (the D8/spec guardrail overrides the README's tidiness step).

**D8 — Observe, never repair; verbatim, never summarize counts.**
The agent must not edit tests/config to green, must not add retries, must not delete evidence, and must report counts and failing sets verbatim (the masking-hazard and vacuous-pass lessons from §15). An out-of-envelope result is reported with a stop-and-investigate recommendation, not "fixed".

**D9 — One agent, room for a family; CI-inspect is a mode, not a sibling.**
The `xtty-` prefix namespaces future agents, but each is maintenance surface — new members only when a recurring noisy workflow proves itself (the bar capture-research passed). CI-run classification shares this agent's logic, so if built it becomes a mode of this agent (a fifth matrix column), not a second agent.

## Risks / Trade-offs

- [Agent prompt drifts from reality (rigs/paths change)] → numbers/workflow deferred to `packer/README.md` at runtime (D2/D7); the prompt holds only procedure + discipline; AGENTS.md names the deference chain so doc updates propagate.
- [Auto-delegation misfires (agent spawned for a non-suite task, or missed for a suite task)] → the AGENTS.md rule is the arbiter; description match is assistive. Misses cost only inline noise (today's status quo); false fires are visible and cheap to cancel.
- [Graphics tier needs a display / user presence] → graphics tier is opt-in (full sweep), and the report notes when it was skipped; headless is the acceptance-bearing tier.
- [Long-running agent dies mid-sweep (SSH drop, VM wedge)] → the report skeleton includes per-tier status; a partial sweep returns partial results + the cleanup manifest (rigs left up for resume by hand).
- [Foreground tool timeouts kill long tiers] → Claude Code's Bash tool defaults to 120 s (600 s hard max) — below every tier ≥1 (local ~5 min; VM ~7 min/run + boot). The agent prompt mandates background execution (`run_in_background`/nohup → log file) with sparse 30–60 s polling, which also bounds the main in-agent context-growth source over a 25–35 min sweep.
- [The evidence dir path (`~/Downloads/xtty-vm-poc/artifacts/`) is machine-local convention] → acceptable for solo tooling; the path is stated in one place (the agent prompt) and echoed in every report.

## Migration Plan

Additive tooling: land the files + doc edits, verify git tracking (exception works, machine-local files stay ignored), then a live smoke: invoke the agent for a Tier-0+1 quick confirm and check the report skeleton. Rollback = delete the files and revert the doc edits; nothing depends on it.

## Open Questions

- None blocking. (Deferred by decision: CI-inspect mode; family members; per-task delegate markers.)
