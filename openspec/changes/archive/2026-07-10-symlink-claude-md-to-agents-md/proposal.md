## Why

`CLAUDE.md` is a regular file that Claude-Code-imports `AGENTS.md` via `@AGENTS.md`, then appends a "Notes for Claude Code" section repeating content AGENTS.md's Building/Conventions/How-to-work-here sections already say in more depth. The import already prevents the two files' *shared* content from drifting (Claude Code inlines AGENTS.md's bytes at load time, measured — `research/03-analysis/agents-md-context-budget.md` §6), but the setup still relies on nobody adding stray content after the import line, and the appendix is dead weight. Replacing `CLAUDE.md` with a symlink to `AGENTS.md` makes the two files byte-identical by construction instead of by import-plus-review-discipline, and drops the redundant appendix — maximally boring, maximally DRY.

## What Changes

- Delete `CLAUDE.md` as a regular file (its `@AGENTS.md` import and the redundant "Notes for Claude Code" appendix) and replace it with a symlink: `CLAUDE.md -> AGENTS.md`.
- Update `AGENTS.md`'s two self-references to the mechanism so they stay accurate:
  - Line 3: `"CLAUDE.md imports it"` → `"CLAUDE.md symlinks to it"`.
  - Line 61 (repo-tree comment): `# imports AGENTS.md (Claude Code entry point)` → `# symlink to AGENTS.md (Claude Code entry point)`.
- No product code, build system, or test changes.

## Capabilities

### New Capabilities
- `agent-guide-parity`: the project maintains exactly one canonical, tool-agnostic AI-agent/contributor guide (`AGENTS.md`); tool-specific entry points (e.g. `CLAUDE.md`) carry no independently-editable content of their own and are structurally guaranteed identical to it (a symlink, not an import-plus-review-discipline convention).

### Modified Capabilities
None — no existing `openspec/specs/` capability's requirements change. (This is a meta/tooling capability parallel to `build-workflow`'s own framing — "constrains the developer workflow and its documentation, not app runtime behavior" — and to `research-capture`/`test-validation`/`ci-investigation`/`coherence-review`/`research-orchestration`, all of which are process/tooling capabilities rather than product features.)

## Impact

- **Files:** `CLAUDE.md` (regular file → symlink), `AGENTS.md` (two one-line textual corrections).
- **Mechanism:** Claude Code's context load is unaffected in substance — it reads the same `AGENTS.md` bytes either way (import vs. symlink resolution); no token-budget change expected. Re-verify by effect per the existing guidance in `agents-md-context-budget.md` §6 (fresh-session `/context` Memory-files size should be unchanged, ~12k).
- **Tooling/portability:** git tracks the symlink as a `120000` blob storing the link target `AGENTS.md`. Low risk here — this repo is macOS-only for contributors and CI runs on `macos-26` runners, both of which resolve symlinks natively (git's default `core.symlinks=true` on macOS/Linux).
- **No other file depends on `CLAUDE.md` being a non-symlink regular file** (repo-wide grep confirmed only `AGENTS.md`'s own two self-references above; `HISTORY.md` and `research/` mentions are dated narrative/analysis text, left as-is per the project's convention that research snapshots are dated and not retroactively edited).
- **Out of scope:** no change to what AGENTS.md's content says beyond the two mechanism references above; no change to the `slim-agents-context` rules/history split.
