## Context

`CLAUDE.md` today is a real, tracked file: an intro line, Claude Code's `@AGENTS.md` import directive, and a "Notes for Claude Code" appendix (3 bullets). The import already means Claude Code loads `AGENTS.md`'s bytes exactly once per session — measured in `research/03-analysis/agents-md-context-budget.md` §6 (fresh-session `/context` Memory-files ≈ 12k tokens = slim AGENTS.md + CLAUDE.md + MEMORY.md, not double-counted). The appendix's three bullets ("treat AGENTS.md as source of truth," "build/test via the Makefile," "use Conventional Commits + OpenSpec") each restate content AGENTS.md's own Building/Conventions/How-to-work-here sections already carry in more depth — auditing the appendix against AGENTS.md's body found no non-redundant content in it.

The goal (per user request) is to make the "CLAUDE.md vs AGENTS.md" relationship maximally boring and DRY: a single source of truth, byte-identical by construction, not by import-plus-review-discipline.

## Goals / Non-Goals

**Goals:**
- Guarantee `CLAUDE.md` and `AGENTS.md` can never diverge, structurally (not just by convention).
- Drop the appendix now that it's confirmed redundant.
- Keep AGENTS.md's own prose accurate about the mechanism it's describing.

**Non-Goals:**
- Changing anything else in AGENTS.md's content or structure.
- Revisiting the `slim-agents-context` rules/history split — untouched.
- Adding Claude-Code-only guidance anywhere (there is currently none worth keeping; if a genuine Claude-only need arises later, it will require re-opening this decision — see Risks).

## Decisions

**D1 — Symlink (`CLAUDE.md -> AGENTS.md`), not "keep the import and just delete the appendix."**

Two ways to reach "no redundant content": (a) keep `CLAUDE.md` as a regular file containing only `@AGENTS.md` with no appendix, or (b) replace it with a symlink. Chosen: (b).

Rationale: (a) still leaves `CLAUDE.md` an independently editable file — nothing stops content re-accumulating under the import line later (which is exactly how the current appendix got there). A symlink makes divergence structurally impossible: there is no file to add content to. This is the stronger, "maximally boring" version of the same guarantee the import already provides for the shared content, and it costs nothing today because the appendix carries no unique information (see Context).

Functionally the two options are identical from Claude Code's perspective — it reads the same `AGENTS.md` bytes either way, so no token-budget difference is expected between them.

**D2 — Correct AGENTS.md's two self-references to the mechanism, don't leave them stale.**

`AGENTS.md:3` ("CLAUDE.md imports it") and the repo-tree comment at `AGENTS.md:61` ("# imports AGENTS.md") both assert the *previous* mechanism as fact. Since AGENTS.md is itself the file being symlinked to, an accuracy bug here is maximally visible (every reader of the canonical guide sees it). Both become "symlinks to" / "symlink to."

**D3 — Leave dated narrative mentions of "CLAUDE.md imports AGENTS.md" alone (HISTORY.md, research/ docs).**

`HISTORY.md` and `research/03-analysis/agents-md-context-budget.md` describe the import mechanism as it existed when those entries were written (2026-07-06). Per the project's research-doc convention, snapshots are dated and time-sensitive, not retroactively rewritten — a future reader re-verifies current mechanics by effect (e.g., `readlink CLAUDE.md`), not by trusting an old doc. Rewriting historical narrative to match a later mechanism would misrepresent what was true when it was measured.

## Risks / Trade-offs

- **[Risk] A symlink forecloses adding genuine Claude-Code-only guidance later without either polluting the tool-agnostic AGENTS.md or reverting the symlink.** → Mitigation: none needed today (audited: today's appendix had zero unique content). If a real Claude-only need shows up later, reverting to a regular `CLAUDE.md` file is a one-line change; not a sunk-cost trap.
- **[Risk] git symlink portability — tracked as a `120000` blob storing the link target; some platforms/tools don't resolve symlinks transparently.** → Mitigation: this repo is macOS-only for contributors and CI runs on `macos-26` GitHub-hosted runners; both resolve symlinks natively, and git's `core.symlinks` defaults to `true` on macOS/Linux. No Windows contributors or CI in this project today. Low risk, acceptable.
- **[Risk] Cosmetic: opening `CLAUDE.md` in an editor shows `AGENTS.md`'s own `# AGENTS.md — xtty` heading, not a `CLAUDE.md`-branded one.** → Mitigation: none needed — this is expected and correctly communicates "this file *is* AGENTS.md," which is the point.
- **Not a risk, but worth stating:** this is not the first time this repo considered symlinks for tooling — `add-capture-research-tooling`'s D1 rejected a symlink/bootstrap pattern for `.claude/skills`, but for an unrelated reason (avoiding a fresh-clone reconstitution step for files consumed in place). That decision doesn't generalize to this change; no bootstrap step is involved here either way.
- **Not a risk, but worth stating:** the archived `slim-agents-context` change's design.md said "no change to the CLAUDE.md→AGENTS.md import mechanism" — that was scope discipline for that unrelated change (not touching things outside its stated purpose), not a considered rejection of symlinking. Not a prior ruling against this change.

## Migration Plan

1. `git rm CLAUDE.md` (or plain `rm`, since it's tracked — either way git sees it as a delete+add pair with the symlink).
2. `ln -s AGENTS.md CLAUDE.md`.
3. Edit `AGENTS.md` lines 3 and 61 per D2.
4. Verify by effect: `readlink CLAUDE.md` → `AGENTS.md`; `diff CLAUDE.md AGENTS.md` → empty (symlink resolves transparently to `diff`); `git status` shows `CLAUDE.md` with the new symlink mode.
5. No rollback complexity — reverting is `rm CLAUDE.md && git checkout <prior-commit> -- CLAUDE.md` (or just re-author the old regular file) if ever needed.

## Open Questions

None blocking.
