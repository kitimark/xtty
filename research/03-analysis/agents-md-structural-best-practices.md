# AGENTS.md structural best practices — external survey for a future revamp

**Provenance:** 2026-07-10, produced via `/xtty:research` (a 5-reader `sonnet` fan-out → synthesis
`opus·high` → adversarial critic `opus·xhigh` → verify-by-effect, workflow `wf_087ea17f-8f6`), plus two
follow-up probes the orchestrator ran directly after two verify-stage agents hit transient API errors.
Sources: Claude Code's official memory docs (fetched live twice), the `agents.md` spec site (WebFetch +
cross-checked against its source), `github.com/agentsmd/agents.md` (cloned), `github.com/openai/codex`
(cloned, pinned at commit `6138909`), `github.com/apache/airflow` (cloned). This is **research only** —
no OpenSpec change was proposed or implemented; it feeds a future `/opsx:propose` for revamping xtty's own
`AGENTS.md`.

**TL;DR:** xtty's `AGENTS.md` is 206 lines but **68,897 bytes** (~333 chars/line) — it passes a naive
line-count check while failing every source's density guidance by a wide margin. The regrowth is not new:
`slim-agents-context` (see [context-budget](agents-md-context-budget.md)) already split narrative into
`HISTORY.md` once, on 2026-07-06 (74,268 → 33,716 bytes); the diet's gain was **fully eroded within
~4–5 days** and the regrowth rate did not slow down (§1b) — the current bloat is the "Keep progress
current" rule's own **table-row bound getting violated** (narrative crept back into cells), not a novel
structural problem. Measuring the actual per-section byte distribution (§1a) — not assumed from a skim —
shows the **"Shipped and archived" table (25.9%) and "How to work here" (23.4%) together are essentially
half the file**; the "Snapshot" paragraph, while a real and unanimously-flagged offender, is a much smaller
lever (8.4%) than a first read suggests. Several plausible-sounding recommendations did **not** survive
adversarial critique + re-verification (§3) — most importantly, **do not use `airflow`'s or `codex`'s byte
count as a size target**, and **do not try to externalize rules into `.claude/rules/`** (that directory is
gitignored in this repo and would never ship).

## 1. Measured baseline (xtty, verified against disk this session)

- `AGENTS.md`: 206 lines / 68,897 bytes / ~333 chars per line average (`wc -l -c`).
- `HISTORY.md`: 166,419 bytes; its own header states the per-change narratives were "moved verbatim out
  of AGENTS.md" by the archived `slim-agents-context` change — so the current density is **regrowth**, not
  a new problem shape.
- `CLAUDE.md` is a real filesystem symlink to `AGENTS.md` (`lrwxr-xr-x`, confirmed via `ls -la`), not an
  importing wrapper — the already-landed `symlink-claude-md-to-agents-md` change.
- Zero `@import`-style lines exist in `AGENTS.md` (`grep -nE '(^|[^`])@[A-Za-z0-9_./~-]+'` → no matches):
  all cross-references (`[HISTORY.md](HISTORY.md)`, research doc links) are plain markdown links, the
  context-cheap form — already the right mechanism, just under-leveraged for the sections that are dense.
- xtty is **not** a monorepo: one root `AGENTS.md` + its `CLAUDE.md` symlink; `XttyCore` is a plain SPM
  package directory with no nested `AGENTS.md`/`CLAUDE.md` anywhere.
- The `AGENTS.md` "Keep progress current" rule already states a status-table row is "bounded: state +
  one-liner + detail pointer — **never a narrative paragraph**" (grep-verified present). The rule exists;
  it just isn't being followed in every row today.

### 1a. Per-section byte distribution (measured, not estimated)

Sliced by line range (`sed -n 'A,Bp' AGENTS.md | wc -c`) against the section/sub-block boundaries found via
`grep -n '^#'` and `grep -n '^\*\*'`:

| Section | Bytes | % of file |
| --- | --- | --- |
| **Shipped and archived** (table, `## Current status`) | 17,863 | 25.9% |
| **How to work here** | 16,121 | 23.4% |
| **Learned refutations** (`## Current status`) | 8,671 | 12.6% |
| Building (incl. CI) | 7,656 | 11.1% |
| OpenSpec workflow | 6,068 | 8.8% |
| **Snapshot paragraph** (`## Current status`) | 5,768 | 8.4% |
| Conventions | 1,563 | 2.3% |
| Open-changes table (`## Current status`) | 1,214 | 1.8% |
| Repository structure | 1,198 | 1.7% |
| Tech stack | 756 | 1.1% |
| Product values | 582 | 0.8% |
| Established specs line (`## Current status`) | 516 | 0.7% |
| Key references | 376 | 0.5% |
| header/preamble (lines 1–8) | ~524 | 0.8% |
| **Total** | 68,897 | 100% |

This corrects an unmeasured claim the first draft of this doc made: the "Snapshot" paragraph is real
(8.4%) but is **not** the single biggest lever — the **Shipped-and-archived table is more than 3x bigger**
(25.9%), and **How to work here is nearly as big as the table** (23.4%). Together the three
`## Current status` sub-blocks (Shipped table + Learned refutations + Snapshot) are **46.9%** of the whole
file, and adding "How to work here" brings the top two sections alone to **49.3%** — essentially half the
file lives in exactly the two places §5 below now ranks first. See §5 for the re-ranked recommendations.

### 1b. Growth trajectory (measured via `git show <sha>:AGENTS.md | wc -c` at the last commit of each day)

| Date | Bytes |
| --- | --- |
| 2026-06-27 | 9,094 |
| 2026-06-28 | 23,549 |
| 2026-06-29 | 42,074 |
| 2026-06-30 | 48,982 |
| 2026-07-01 | 54,159 |
| 2026-07-02 | 55,520 |
| 2026-07-03 | 60,439 |
| 2026-07-04 | 66,318 |
| 2026-07-05 | 74,268 (pre-diet peak) |
| **2026-07-06** | **33,716** (`slim-agents-context` split lands same day) |
| 2026-07-07 | 41,071 |
| 2026-07-08 | 55,395 |
| 2026-07-09 | 64,400 |
| 2026-07-10 | 68,897 (today) |

Pre-diet growth (06-28 → 07-05, end-of-day sizes): +50,719 bytes / 7 days ≈ **7.2 KB/day**. Post-diet
regrowth (07-06 → 07-10): +35,181 bytes / 4 days ≈ **8.8 KB/day** — the regrowth rate is **not slower**
than before the diet; if anything it's running faster by this measurement. At the current rate the file
will **exceed its pre-diet peak (74,268 bytes) within about one more day** — i.e. the "Keep progress
current" table-row-bound rule bought roughly 4–5 days of headroom before the underlying violation (narrative
creeping back into table cells) put the file back on the same trajectory. This is a sharper, dated version
of the "regrowth, not novel structure" claim in the TL;DR — re-verify by re-running this exact `git show`
loop against dates after 2026-07-10 (see §6).

## 2. Cross-source findings (structural, not byte-count comparisons)

| Practice | Claude Code docs | agents.md spec | agentsmd/agents.md repo | openai/codex | apache/airflow |
| --- | --- | --- | --- | --- | --- |
| Bullets/headers over dense prose | explicit ("organized sections are easier to follow than dense paragraphs") | shown by example | both example files are flat bullet lists | root is "almost entirely bullet lists... essentially no narrative prose" | same — headed bullet sections throughout |
| Link out instead of inlining detail | `@import` still loads in full (a caveat, not a recommendation to inline) | explicit rationale (README=humans, AGENTS.md=agent detail) | site link-outs instead of vendoring examples | links to `styles.md`, `app-server/README.md` rather than restating | links to 30 numbered `contributing-docs/*.rst` files; `ui/AGENTS.md` defers setup entirely |
| Embed changelog/narrative history inline | not addressed | not addressed | not addressed | **no** (re-verified, see §3) | **no** (re-verified, see §3) |
| Nest per-subproject in a monorepo | n/a (single-repo feature not covered) | explicit: nearest file wins | cites "the main OpenAI repo has 88 AGENTS.md files" | yes — 88 files, incl. a 12-line same-crate scoped reminder | yes — 17 files, from a 578-line standalone sub-app down to 14-line leaf reminders |
| Symlink `CLAUDE.md -> AGENTS.md` | endorsed (or `@AGENTS.md` import; import required on Windows) | FAQ prescribes `mv AGENT.md AGENTS.md && ln -s AGENTS.md AGENT.md` | n/a | no `CLAUDE.md` found | **uses the identical symlink pattern**, verified byte-identical |
| Explicit size/conciseness target | **yes** — "target under 200 lines... shorter files produce better adherence" | **no** — FAQ: "no required fields... any headings you like" | no separate style rubric beyond a 4-step how-to | n/a (no stated target; 322 lines/22.5KB observed) | n/a (no stated target; 519 lines/35KB observed) |

Precedence (where nesting exists) is unanimous across every source that addresses it: nearest/deepest file
wins; a direct user/chat prompt overrides all agent-file content; content loads root-to-cwd. Moot for xtty
today (single root file) but the rule to know if nesting is ever added.

Two mechanisms surfaced by this session's own **direct** re-verification of the Claude Code docs (not
originally captured by the reader agent, since the first fetch was summarized) are new to this repo's
research corpus:

- **Block-level HTML comments in `CLAUDE.md`/`AGENTS.md` are stripped before injection into context** —
  "Use them to leave notes for human maintainers without spending context tokens on them... comments
  inside code blocks are preserved. When you open a CLAUDE.md file directly with the Read tool, comments
  remain visible." A zero-token channel for maintainer-only notes.
- **`.claude/rules/*.md`** (path-scoped, `paths:` frontmatter, loads only when Claude touches matching
  files) is a real Claude-Code mechanism for externalizing large, situational sections — but see the fates
  table below for why it doesn't apply here.

## 3. Fates table — claims the first-pass synthesis got wrong, and one that held up

The first synthesis pass overstated several claims. The critic caught them; the ones needing an external
check were then verified by effect (not re-argued from memory). Recording them here, per this repo's
capture-depth convention, so they don't respawn in a later pass. The last row is different from the rest —
it's a claim the critic flagged as *unverified*, not *wrong*, and re-verification confirmed it holds;
included for completeness since the whole "move narrative out" recommendation rests on it.

| Claim (as first stated) | Fate | Killed/corrected by |
| --- | --- | --- |
| "xtty's 68.9KB would be **silently** truncated by a Codex consumer" | ❌ | Read `codex-rs/core/src/agents_md.rs` directly: truncation fires `tracing::warn!(path, remaining_bytes, "project doc exceeds remaining budget; truncating")` — a structured warning, not silent. Also **conditional**, not live: the 32KiB `project_doc_max_bytes` cap only binds if a Codex-class agent reads the file; via the `CLAUDE.md` symlink, only Claude Code (no such cap) consumes it today. |
| "All sources converge that xtty is too dense" | ❌ | `agents.md`'s own FAQ is explicitly inclusive ("no required fields... any headings you like") with **no** stated size ceiling — refetched the live page directly (`curl` + grep for "claude\|symlink\|size\|length\|concise\|character": zero hits beyond an unrelated README-conciseness line). Only Claude Code's docs state a size/adherence norm. `codex`/`airflow` are large real files, not endorsements of largeness. |
| "Halve to ~30–35KB (airflow's root size) as the target ceiling" | ❌ | No source calls airflow's or codex's file exemplary or well-adhered-to; matching a peer's byte count is an arbitrary anchor. Airflow's 519-line root arguably violates Claude's own <200-line guidance. The only defensible normative target is Claude's own (<200 lines, shorter=better adherence), re-confirmed verbatim on live refetch 2026-07-10. |
| "Codex's `docs/` scoping rule shows AGENTS.md curation discipline" | ❌ | The quoted rule ("Do not add general product/user-facing documentation to the `docs/` folder") governs the `docs/` **directory**, not `AGENTS.md` content scope — misattributed. |
| "Claude docs: context the agent needs at a decision point must be present" (used to justify keeping delegation rules inline) | ❌ | No such sentence exists in the docs — it was the synthesis's own reasoning dressed as a quote. The real, narrower, quotable basis still supports the same conclusion: "Project-root CLAUDE.md survives compaction: after `/compact`, Claude re-reads it from disk and re-injects it... Nested CLAUDE.md files in subdirectories are not re-injected automatically" (re-verified verbatim on live refetch). |
| "Adopt airflow's START/END sentinel pattern" (stated as a direct recommendation) | ⊘ downgraded | Airflow's sentinels wrap **tool-generated** content (a commands block, a doctoc TOC) — xtty's snapshot/counts are hand-maintained with no generator. Sentinels alone add no drift protection without building the regeneration tooling first; keep as a future option, not a direct action. |
| "Move the OpenSpec-workflow section to a path-scoped `.claude/rules/*.md` file" | ❌ dead end in this repo | Confirmed against xtty's own `.gitignore`: `.claude/*` is ignored, with un-ignore exceptions only for `.claude/commands/xtty/`, `.claude/skills/xtty-*/`, and `.claude/agents/xtty-*`. No exception for `.claude/rules/` exists, so anything placed there is **never committed, never shared with teammates or CI**. A plain committed linked doc is the only workable externalization form here. |
| "None of the 5 external examples embeds changelog/narrative history inline" | ✅ confirmed | Re-ran the exact grep this session: `grep -niE 'changelog\|## 20[0-9][0-9]\|history of\|narrative'` against the cloned `codex`/`airflow`/`agentsmd` `AGENTS.md`/README files. The only hits were false positives unrelated to embedded project changelogs — codex's "history (of messages)" is its own LLM-context feature, airflow's "changelog" hits are newsfragment/release-process *instructions* (how to update a separate `.rst` changelog), not inline narrative. Zero real embedded changelogs found. |

## 4. Reproducible probes (what each proves, and what it can't)

1. **Byte/line density check:** `wc -l -c AGENTS.md` + `awk '{print length}' AGENTS.md | ...` for
   chars/line. Proves the naive "under 200 lines" check is misleading here (206 lines, 68.9KB) — it cannot
   by itself say *which* sections are the offenders; pair with a per-section grep/byte breakdown (not done
   this session — a natural follow-up for whoever authors the revamp change).
2. **Changelog-absence grep:** `grep -niE 'changelog|## 20[0-9][0-9]|history of|narrative'` against a
   cloned source's `AGENTS.md`. Proves the string doesn't appear as an embedded changelog; **cannot** prove
   a file has zero historical content phrased differently — read matches by hand (both hits here were
   confirmed false positives, not skipped).
3. **Live doc re-fetch for currency:** `WebFetch` (or `curl`) directly against `https://code.claude.com/docs/en/memory`
   and grep the returned markdown for the exact target phrases ("target under 200 lines", "survives
   compaction", "not re-injected automatically"). Proves the guidance is current as of the fetch date;
   **cannot** prove future stability — these are version-sensitive docs, re-check before citing again.
4. **Gitignore-scope check:** `grep` xtty's `.gitignore` for `.claude/rules` / the existing un-ignore
   exceptions. Proves whether a proposed externalization mechanism would actually ship; **cannot** prove
   the file wouldn't work locally for the author alone (it would — it's just invisible to everyone else and
   to CI, which is the actual disqualifier for team-shared rules).
5. **Dead end avoided:** re-fetching `agents.md` twice (WebFetch, then raw `curl`) to settle whether a
   size/CLAUDE-compat statement was dropped by WebFetch's summarization pass — it wasn't; both fetches
   agree the page is silent on both points. Worth noting because the first reader's `openQuestions` flagged
   exactly this doubt, and it would have been wrong to resolve it by re-reading the same WebFetch summary
   again instead of hitting the raw HTML.

## 5. Recommendations for a future OpenSpec change (not implemented here — directional only)

These are inputs for whoever authors the actual revamp change (likely via `/opsx:propose`); this research
doc takes no position on scheduling it. **Ranked by measured byte impact (§1a)**, not by first impression —
the first draft of this doc led with the Snapshot paragraph before the per-section measurement existed;
the two sections below actually account for essentially half the file.

1. **Collapse "Shipped and archived" table cells** (17,863 bytes / 25.9% — the single biggest section in
   the file) from multi-clause narrative prose to one line each (name + one clause + pointer to
   `HISTORY.md`), or drop per-change rows in favor of the existing Foundation/Multiplexing/Semantics group
   table + a single "full narratives: `HISTORY.md`" pointer. Highest measured lever, and unanimously
   supported — no external source's example contains per-change narrative prose at all.
2. **Compress "How to work here"** (16,121 bytes / 23.4% — nearly as large as #1). This section holds the
   delegation-boundary rules for the 3 standing agents + 1 Workflow launcher, each currently written as a
   prose paragraph with embedded mechanism/forensic justification. Keep the rules inline (they're
   always-on, decision-time content — see rationale below) but compress each to claim + conclusion +
   pointer, moving the "why the marker exists" narrative to the already-linked research docs.
3. **Compress "Learned refutations"** (8,671 bytes / 12.6%) to one line each — these are durable
   never-re-propose rules, exactly what belongs in an always-loaded file per Claude's own docs, but each
   currently carries multiple lines of embedded mechanism. Keep claim + conclusion + pointer to the
   research doc that settled it (each already has one).
4. **Externalize the verbose OpenSpec-workflow / "keeping a change coherent" walk-list** (6,068 bytes /
   8.8%) to a plain committed linked doc (**not** `.claude/rules/` — confirmed gitignored/non-functional in
   this repo, §3), keeping a compressed inline summary plus the cheap, high-consequence gotchas (4-hashtag
   scenarios, MODIFIED-must-paste-whole-block).
5. **Kill the run-on "Snapshot" paragraph** (5,768 bytes / 8.4%) → a short bulleted status block (milestone
   position, authoritative test envelope + pointer to `packer/README.md`, "latest change: X, see
   `HISTORY.md`"). Real and unanimously supported, but a smaller lever than #1–#2 by measured bytes — do it
   because it's cheap and universally recommended, not because it's the biggest win.
6. **Don't nest `AGENTS.md` files.** xtty is a single app + one small SPM package, not a monorepo of
   differently-stacked subprojects — the bar every real nesting example clears (airflow's `registry/` is a
   578-line standalone front-end sub-app; even the *narrow* nested examples like codex's `bottom_pane/` or
   airflow's `_shared/` exist because there's a genuinely separate directory boundary to scope to).
7. **Consider HTML-comment-wrapping** any content useful to a human reading the file directly but not
   worth spending agent context tokens on (the newly-confirmed zero-cost mechanism).
8. **Frame any size goal as Claude Code's own guidance** (<200 lines, shorter=better adherence), not a
   peer file's byte count — treat `codex`/`airflow` as structural examples (bullets, link-out, symlink,
   selective nesting), not size targets.
9. **Treat this as re-enforcing an existing, already-violated rule**, not inventing new structure — the
   "Keep progress current" rule already bans narrative paragraphs in table rows; §1b shows the diet's gain
   fully eroded within ~4–5 days and the regrowth rate did not slow down. The fix is discipline (and maybe a
   coherence-critic check for row/section length), not a new mechanism — a second diet without that
   guard will regrow just as fast.

## 6. Re-verify by effect

Re-run `wc -l -c AGENTS.md` after any revamp change lands — the byte count should drop sharply (target:
well under the current 68.9KB) while the line count may not move much (the fix is prose density, not line
count). Re-slice the per-section breakdown (§1a's `sed -n 'A,Bp' | wc -c` method) and confirm the
Shipped-and-archived table and "How to work here" actually shrank — those are the two sections the revamp
should target first per the measured ranking, so a revamp that only touches the Snapshot paragraph would
leave ~49% of the file untouched. Re-run the §1b growth-trajectory loop
(`git log --follow --reverse --format='%H %ad' --date=short -- AGENTS.md`, `git show <sha>:AGENTS.md | wc -c`
per day) after the revamp change lands and again a week later — if the post-revamp growth rate is still
≥8.8KB/day, the "Keep progress current" table-row bound is still being violated and the revamp didn't fix
the underlying discipline gap, only the symptom. Re-check `grep -c '<!--' AGENTS.md` if HTML-comment
wrapping is adopted, and confirm via a fresh `/context` that those bytes don't appear in the loaded
Memory-files token count (comments are stripped before injection — verify this isn't just a documentation
claim by diffing `/context` token counts before/after adding a large HTML-commented block). If nesting is
ever considered later, re-verify the precedence rule live (nearest-file-wins) rather than assuming it from
this doc.

## 7. Reusable guideline

1. **Line count is not the density metric — bytes/chars-per-line catch what "under 200 lines" misses.**
   A file can pass a naive line-count gate while being 3x denser than a well-regarded 500-line peer file.
2. **A peer's file size is a data point, not a target** — only cite a normative guideline (here: Claude
   Code's own docs) as the size target; large real-world examples show *structure* is transferable
   (bullets, link-out, symlink, selective nesting) even when their *size* isn't something to imitate.
3. **Check gitignore scope before recommending any externalization mechanism** — a `.claude/`-nested
   mechanism that looks perfect in the vendor docs can be a dead end in a specific repo's own ignore rules.
4. **Adversarial critique catches misattributed quotes and invented sentences dressed as sourced facts** —
   several of this session's first-pass claims read as directly quoted but weren't; a critic pass that
   demands "show me the exact source line" is worth running before committing recommendations to a doc.
5. **Grep-based absence claims need the matches read, not just counted** — both "changelog" hits in this
   session's verification were false positives; a probe that returns non-zero doesn't automatically refute
   the claim it was testing.

## Sources

- Claude Code memory docs: `https://code.claude.com/docs/en/memory` (fetched 2026-07-10, refetched live
  twice this session for the size-target and compaction-behavior claims)
- `https://agents.md/` (WebFetch 2026-07-10; cross-checked via raw `curl` + the cloned source repo since
  WebFetch summarizes rather than returning raw HTML)
- `github.com/agentsmd/agents.md` — cloned `--depth 1` to `/tmp/xtty-research-agentsmd-repo`
- `github.com/openai/codex` — cloned `--depth 1 --filter=blob:none` to `/tmp/xtty-research-openai-codex`,
  pinned at commit `6138909` ("Keep unified exec output collection bounded (#32150)")
- `github.com/apache/airflow` — cloned `--depth 1 --filter=blob:none` to `/tmp/xtty-research-apache-airflow`
  (13,448 tracked files even shallow-cloned)
- Workflow transcript: `wf_087ea17f-8f6` (5 readers + synthesis + critic + verify stages, 819,859 subagent
  tokens, 79 tool uses)
- Prior art this complements: [AGENTS.md context budget](agents-md-context-budget.md) (the `slim-agents-context`
  measurement this doc's baseline regrowth builds on)

Note: this is a snapshot as of 2026-07-10 — the external docs/repos are living sources and could drift;
re-verify version-sensitive claims (the Claude Code size target, the Codex byte cap) before citing them far
in the future.

## Addendum (2026-07-10, later same day): Tooling-row rotation & enforcement

**Provenance:** two further `/xtty:research` fan-outs, prompted by an explore-mode session that dug into
*why* the file is dense: (1) a 7-reader `sonnet` pass over docs/spec sources (towncrier, Keep a Changelog,
product changelogs, doc linters, `gh`-search for CI precedent, `actions/stale`/Dependabot) → synthesis
`opus·high` → critic `opus·xhigh` → verify (`wf_4c74a2c1-e41`); (2) a 6-reader pass **cloning large-scale
OSS source directly** (`cpython`, `pytest`, `kubernetes`, `vscode`, `django`, `rust-lang/rust`) → same
pipeline (`wf_9388669b-d9f`, resumed once after a transient critic-stage API error). Both converged
independently; findings below are reconciled across both, not from either alone.

**The concrete target, precisely characterized this round:** AGENTS.md's "Shipped and archived" table has
6 rows. Five (P0–P7 phase milestones) total ~1.2KB and never grow — each phase is *closed*. The sixth,
"Tooling," is 16,645 bytes (93% of the table, 24% of the whole file): ~24 change narratives bracketed
into one cell, with no closing event. **The mechanism, named:** the phase rows stay bounded because they
are edited only when a new *phase* closes (rare, and each closes forever); the Tooling row is instead
*change-keyed* — every archived tooling change appends to the same cell. The fix is not "make it shorter,"
it is **make it category-keyed like its siblings**: replace the cell with a bounded index (e.g. "Tooling —
CI, dev-workflow agents, install, signing, test-image, launchers; full narratives → HISTORY.md"), edited
only when a genuinely new *category* appears, never per-change. Verified safe: all ~24 items' narratives
already exist in HISTORY.md (the 5 oldest individually confirmed present) — the sweep is a pure deletion
from AGENTS.md, zero information loss. The same anti-pattern (and the same fix) applies to the 5.8KB
Snapshot paragraph named in §5 above — bundling both is a completeness point the first pass under-scoped.

**Cross-project rotation patterns (5 distinct, all real-world, all release-cadence-anchored):**

| Pattern | Project(s) | Mechanism | Fit for xtty |
| --- | --- | --- | --- |
| A — fragment files, merged & deleted at a cut | pytest (towncrier), cpython (own tool, `blurb` — **not** towncrier) | one file per change in a directory; a release event merges + deletes them | needs a release cut xtty lacks; solves a concurrent-PR conflict problem xtty (solo, push-to-main) doesn't have |
| B — PR-metadata extracted at release | kubernetes | a fenced block in the PR body; an external generator queries merged PRs by label since the last tag | needs a PR-centric workflow + bot; heaviest of the five, justified only at thousands-of-PRs scale |
| C — one file per release, from day one | vscode (in the separate `vscode-docs` repo) | a placeholder file created weeks ahead, edited incrementally by many contributors on a shared branch, frozen after ship (not literally immutable — patch-release addenda land for weeks) | no shared growing bucket, but needs an index and a multi-editor cadence xtty (solo) doesn't have |
| D — one shared file, skeleton-scaffolded, edited in place, frozen at cut | django | a skeletoned file per version; every PR edits its own section directly; frozen at release | highest merge-conflict risk of the five (irrelevant for a solo repo), zero tooling |
| E — label-tracked, human-assembled | rust-lang/rust | a self-service `relnotes` label; a human periodically queries it and hand-writes the next frozen section | **closest philosophical fit** — no fragment files, no generator — but xtty needs even less: the OpenSpec change directory already *is* the per-change queue, no label required |

**Load-bearing insight, common to all five:** every pattern is anchored to a periodic *release cut* that
sweeps the accumulation zone. xtty has git tags (`v0.0.1`) but no release cadence, so importing any of
A–D would recreate an unbounded bucket, just with more machinery. xtty's actual cut point is the per-change
OpenSpec *archive* event (already fires reliably), and its permanent archive (HISTORY.md) already plays the
role of RELEASES.md/changelog.rst. Nothing needs to be imported — the fix is applying xtty's own
already-honored invariant (the "Open changes" table is already category-/row-per-change and clears) to the
one row that doesn't.

**Enforcement — a real, unresolved tension, not a settled answer.** The two fan-outs' critics disagreed,
and the disagreement is informative rather than contradictory once stated precisely:
- The first critic rejected a **mandatory CI ratchet** as disproportionate — xtty pushes straight to `main`
  (no PR to hang a path-scoped gate on), so a hard byte ceiling would either rarely fire or red the repo on
  legitimate growth.
- The second critic rejected **overselling a REVIEW-severity critic heuristic** as a fix — xtty already has
  a *written* rule ("never a narrative paragraph") that the Tooling cell violates *right now*, and the
  in-flight `harden-test-precision-vs-claim` change's own Risks section states a REVIEW-level heuristic "can
  be, and by design sometimes should be, ignored by a human reviewer." Its sufficiency is untested, not
  proven.

Both are right, and they narrow the option space rather than cancel out: a **critic heuristic is the
proportionate primary mechanism** (matches xtty's existing `xtty-openspec-critic` machinery and the
in-flight precedent; a real CI/bot gate at pytest/cpython/kubernetes's scale is confirmed — via live `gh
api` branch-protection checks — to be genuinely required/merge-blocking machinery, justified only by
contributor counts xtty doesn't have), but its sufficiency should be **measured, not assumed** — track the
Tooling row's (and Snapshot paragraph's) byte size after each of the next several archives once a heuristic
lands. The now-crisp, checkable version of that heuristic: *does a reconcile append a per-change narrative
to a row that should only change per-category?* — a structural check, not a fuzzy length judgment. Whether
to also add a cheap non-blocking byte/char warning as a backstop (real, working precedent exists —
`konflux-ci`, `tektoncd/catalog`, `cloudposse/atmos`, `homeassistant-ai/ha-mcp` all gate `AGENTS.md`
specifically with a plain `wc` shell step) is left as an open option for whoever proposes the actual fix —
this research doc states the tradeoffs, it does not pre-decide them.

**Fates table (corrected during critique + verify):**

| Claim | Fate | Corrected by |
| --- | --- | --- |
| "cpython's 431-fragment pile proves a bucket goes unbounded without a sweep" | ❌ | verify (full unshallow clone): 205 deletion commits, one cluster per release, roughly monthly — cpython *does* sweep; the pile is large because of PR volume relative to project scale, not absence of sweeping |
| "a cpython fragment sat unswept for 7 years (2019→2026)" | ❌ | verify: the 2019 date is in the *filename*, not the fragment's actual residency — `git log --diff-filter=A` on that exact file shows it was added and swept within the same 2026 release cycle (4 days) |
| "pytest sweeps its fragment dir every few weeks" | ❌ unsupported | the project's own version dates show a ~4-month gap (9.0.2→9.0.3); the observed 4-fragment snapshot was just shortly after a release, not evidence of a weeks-scale cadence |
| "pytest/cpython/k8s's changelog enforcement is advisory, not confirmed-blocking" | ↑ upgraded, not refuted | verify via live `gh api` branch-protection/ruleset checks on all three: all are genuinely required, merge-blocking status checks — stronger evidence than the synthesis first claimed, in the opposite direction of most corrections here |
| "a non-blocking critic heuristic will keep the row bounded ('makes the sweep durable')" | ❌ unproven | the claim is prospective with no present probe; the existing *written* rule already fails right now, and the only in-flight heuristic precedent (`harden-test-precision-vs-claim`) explicitly disclaims guaranteed compliance in its own Risks section |
| "the sweep is safe (no unique content lost)" | ✅ confirmed | grepped HISTORY.md for all 5 oldest Tooling-row items — all present verbatim; by extension the newer ~19 (already known to post-date the doc-conventions capture rule) are equally safe to drop from the cell |

Two measurement bases for the diet numbers both appear across this research and are both correct, not in
tension: the single diet *commit* (`d2a11fd`) cut 80,609→28,493 bytes; the *end-of-day* snapshot (matching
§1b above) reads 74,268→33,716, because other same-day commits landed before/after the cut itself. Cite
whichever basis matches what's being measured.

**Re-verify by effect:** after a Tooling-row/Snapshot fix lands, re-run `grep -n '| Tooling |' AGENTS.md |
wc -c` (today: 16,648) after each of the next several archived changes — it should stay near-constant
(category-keyed), not climb per-change. If a critic heuristic or byte-warning is added, the same measurement
is the test of whether it actually held the line, not whether it merely exists.

**This research has saturated.** Two independent fan-outs, source-verified across a spec-page pass and a
large-OSS-clone pass, converged on the same structural diagnosis and the same open enforcement question.
The honest next step is an OpenSpec proposal for the actual fix, not a further research pass.
