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

---

## Addendum (2026-07-13): the diet regrew a THIRD time — and the enforcement question this doc left open was the WRONG QUESTION

**Provenance:** 2026-07-13, during an `/opsx:explore` fan-out (fable-5 disposition audit · `gpt-5.6-sol`
adversarial pass · a Claude Code docs agent · Opus non-participant re-measurement of every load-bearing
number). All figures measured against disk; none estimated.

### A1. The prediction in §5 rec 9 came true, on schedule

This doc's rec 9 said, in writing, on 2026-07-10:

> *"The fix is discipline (and maybe a coherence-critic check for row/section length), not a new mechanism —
> **a second diet without that guard will regrow just as fast.**"*

`revamp-agents-md` shipped the next day (80,107 → **43,667** bytes, −45.5%). Measured **48 hours later**:

| date | bytes | event |
| --- | --- | --- |
| 2026-07-06 | 80,609 | pre-split peak |
| 2026-07-06 | **28,100** | `slim-agents-context` (−21,548 startup tokens; adherence **improved** 1/3 → 3/3) |
| 2026-07-11 | 80,107 | regrown to pre-split size — **5 days** |
| 2026-07-11 | **43,667** | `revamp-agents-md` (−45.5%) |
| **2026-07-13** | **81,012** | **regrown to pre-diet size — 48 HOURS** |

Startup cost today (`claude -p` instrument, §4 probe 1): **57,569 input tokens** for a session that does
nothing; AGENTS.md is ~32.9k of it @ the measured 2.46 B/token — i.e. **exactly the pre-split 32.8k**.
**The entire 21,548-token saving has been given back, twice.**

### A2. ❗ The guard SHIPPED, the guard HELD, and the file doubled anyway — the finding that matters

This doc closed by leaving enforcement as an open tradeoff: *"a critic heuristic vs. a non-blocking byte
gate."* `revamp-agents-md` chose the **critic heuristic** (`xtty-openspec-critic.md:39` — the REVIEW-severity
**category-keyed status-surface bound**) and recorded that *"sufficiency is tracked, not assumed."*

**It is now measured. The heuristic worked — and it did not matter.**

- The surface it guards **held**: the Tooling row is **1,934 bytes** today (23,097 → 1,374 at the revamp).
- **AGENTS.md still went 43,667 → 81,012.**

⇒ **The growth did not stop; it MOVED.** The forensic narratives that used to accumulate in the Tooling row
now accumulate in the **Learned-refutations** bullets — a surface the heuristic does not cover.

❌ **RETIRED — "critic heuristic vs. byte gate" was the wrong question.** *Both* options are **surface-scoped**,
and **a guard scoped to one surface displaces growth to the next unguarded surface.** Whack-a-mole is not an
implementation detail of the fix; it is a property of every surface-scoped guard. The invariant must govern
**what KIND of content may enter the eager index at all**, not **how big any particular surface is**.

Independently reached by `gpt-5.6-sol`, which named the mechanism without being told the Tooling-row history:
> *"The recurrence mechanism is **uncontrolled admission of forensic narratives into an eager index**."*

### A3. Where the bytes actually are — and why this is NOT a distribution problem

- File: **241 lines / 10,828 words / 81,012 bytes** (Claude Code's own docs recommend a root guide **< 200 lines**).
- **Learned refutations: 32,300 B / 4,471 words = 41% of the file.** 25 bullets, **mean 178 words**, against
  the tier's own written spec — *"add a **one-liner** (with its conclusion)"*.
- Concentration: **top 2 bullets = 54.5% of the tier**; top 5 = 69.8%.
- ❗ **Atomicity census — the decisive measurement: only 2 of the 25 bullets are non-atomic**, and those 2 carry
  **23 of the tier's 23 inline numbered sub-findings** (12 + 11). **The other 23 bullets are already in the
  correct one-liner form.** Both offenders were written within the preceding 48 hours.

⇒ The bloat is **not** a slow, distributed drift that a length rule would catch. It is **two entries that
swallowed a research doc each.**

### A4. ❌ RETIRED at birth — the per-unit WORD CAP (killed by cross-model review, ACCIDENT-class)

Proposed during this explore, and killed the same session by `gpt-5.6-sol` before it reached a proposal:

> *"Split one 1,400-word entry into **twenty-four ≤60-word bullets**. It passes per-bullet lint, preserves
> nearly all the cost, and destroys atomic scanability."*

A word cap bounds the **unit** and leaves the **tier** unbounded — and **bullet-splitting is what an HONEST
session does** when told "keep bullets short" ⇒ **ACCIDENT-class ⇒ fatal** by this repo's own standard.
Three further accident-class failures it constructed:

1. **Delete the qualifications/counterexamples** to fit the cap → *"lint improves while rule correctness
   falls"* — these refutations are half caveats (F10 is mostly caveats); a cap rewards stripping them into
   dangerously **absolute** prohibitions.
2. **Move rationale into ordinary prose or extra table rows** → escapes the meter unless every Markdown
   continuation is counted.
3. At a ceiling, **evict an older load-bearing rule to admit the newest incident** → ***"the guard guarantees
   size, not retention value."***

> *"These are not adversarial evasions; they are **predictable responses to a locally failing lint rule**."*

### A5. ❌ RETRACTED — "ATOMICITY is the invariant that survives" was WRONG (killed by cross-review, same day)

> ⚠️ **The text below was committed in `fb6121e` and is REFUTED. It is preserved, struck, because a fates
> table that hides its own dead claims is worthless.** The refutation came from a **cross-attack review**
> (§A5-bis) in which each model reviewed only the half of the design it did **not** author.

~~*"One entry = one rejected action + its replacement + one evidence pointer. It catches 100% of the observed
bloat and touches nothing that works (only 2 of 25 entries violate it). It is mechanically checkable (grep for
inline `**(N)`). Atomicity defers eviction — atomic entries run ~40–60 words ⇒ 25 entries ≈ 10 KB; the tier
holds 50+ before pressure bites."*~~

**Three independent kills:**

1. ❌ **"Only 2 of 25 are non-atomic" is CIRCULAR.** It is true *only because* "non-atomic" was **defined as
   "contains `**(N)` markers."** Measured: the **tar-pit bullet has ZERO numbered markers** and embeds a
   **six-step chronology plus two rejected actions**; the Local-Network bullet packs **four** refuted
   mechanisms. Under the **semantic** definition, **≥6** entries are non-atomic. **The grep measures a
   STYLISTIC ACCIDENT, not a property.**
2. ❌ **Atomicity is NOT mechanically decidable past that one regex.** *"No embedded chronology/transcript"*
   has no test. It degrades into the **semantic judgment call** class — and this repo has **already measured
   that class failing**: `xtty-openspec-critic.md:39` says so **in its own text** (*"never a BLOCKER, since
   distinguishing a category summary from a narrative append is a semantic judgment call"*) and it **held its
   row while the file doubled**.
3. ❌ **The "defers eviction" escape is quantitatively FALSE.** The file's **own conforming (marker-free)
   bullets** measure **83.8 words / 632 bytes** — *not* 40–60 words. So **25 entries ≈ 15.4 KB** and
   **50 entries ≈ 30.9 KB ≈ today's entire bloated tier (32.3 KB)** — i.e. **a budget large enough to "hold
   50+" would be GREEN on the very disaster that motivated it.** Any budget that *would have fired* leaves
   ~5 entries of headroom, and **one investigation-day produced 12 sub-findings.** ⇒ **Eviction is the
   guard's normal operating regime, in week one — not a deferred residual.**

❗ **And the mutation suite proposed alongside it could not have caught any of this:** all three mutations
(split-into-N · overflow-to-prose · inline markers) are **net-byte-positive**, so the *byte meter* catches all
three. **No mutation was atomicity-only-detectable ⇒ the guard could have shipped with the atomicity check
entirely broken and its own acceptance suite would still have passed.**

### A5-bis. ❗ THE REAL DIAGNOSIS — the rule is NOT missing, and it DOES reach the loop. The disease is ADMISSION.

❌ **RETRACTED — the F7 framing in §A2/§A10 ("nothing enforces it; the rule doesn't reach the loop") is FALSE.**
The original grep covered `.github/`, `scripts/`, `Makefile`, `openspec/config.yaml`, and the critic. **It never
grepped `openspec/specs/` or `.claude/skills/`.** The bound exists at **three** surfaces, all predating both
regrowth episodes:

| surface | what it says | since |
| --- | --- | --- |
| **`openspec/specs/research-capture/spec.md:48`** | a **SHALL-grade established-spec requirement** — *"Reconciling a completed change **SHALL NOT** grow the guide's status surface beyond a bounded entry; narrative content moves to the history log"* (it even defines the **category-keyed** bound) | **2026-07-06** |
| **`.claude/skills/xtty-capture-research/SKILL.md:31-33`** | at the **point of action** — ***"Narrative paragraphs never go here"*** · *"add a one-liner (with its conclusion)"* | with the skill |
| **`.claude/agents/xtty-openspec-critic.md:39`** | the category-keyed status-surface bound (REVIEW) | `ea8bfe1` |

⇒ ❗ **The rule reached the loop at SPEC grade, at the POINT OF ACTION, and at REVIEW time — and was overridden
every single time.** **The disease is not REACH. It is FORCE — and beneath that, ADMISSION.**

**Reached independently by BOTH reviewers** (neither authored the framing they were attacking, so this is a
genuine cross-model agreement rather than an echo):
- `gpt-5.6-sol`: *"**The WRITE RULE is the growth engine.** 'Missing enforcement caused regrowth' is false."*
  With the ledger: **100% of the +37,345 B was INSTRUCTED writing** (archive / capture / reconcile commits) —
  **zero rogue appends.** The rule *orders* the append; **nothing controls ADMISSION to the eager tier.**
- fable-5: *"The disease is not REACH, it is **FORCE and FORM** — every surface asks the writer to judge its
  own append."*

### A5-ter. ⚠️ THE FATAL BYPASS — a naked ceiling CAUSES the damage it exists to prevent

**The compensating strip (ACCIDENT-class ⇒ fatal).** An honest session, mid-capture, holding a **real** new
refutation, hits a red ceiling. **Nothing tells it to stop.** Every incentive says *make CI green*. So it
compresses old entries — and **the cheapest compression is stripping the qualifications** (*"HEDGED (n=1)"*,
*"stated defeasibly"*) — **which is exactly where a rule's CORRECTNESS lives.** **Every meter goes GREENER as
it strips.**

> The design named caveat-stripping as the accident that killed the word cap (§A4) — **and then shipped the
> identical failure mode one level up.** *A guard that forces the model to resolve an eviction dilemma will get
> the dilemma resolved the cheapest way.*

### A5-quater. ✅ THE SURVIVING DESIGN — admission control · a dumb meter · a human stop

1. **Fix the WRITE RULE — control ADMISSION, not size** *(the real fix; nothing else addresses the driver)*.
   Amend the **instructing** surfaces (`xtty-capture-research/SKILL.md`, `research-capture/spec.md`):
   **`HISTORY.md`/the research doc is the DEFAULT destination**; appending to the eager tier is the
   **exception**. Admission needs an explicit decision-time test (*"absent this line, would a future session
   re-propose the refuted thing?"*) **and a MERGE-OR-REPLACE step** — which makes the tier a **fixed-size
   cache, not an append log.** *(Both reviewers reached the merge-or-replace requirement independently.)*
2. **A BLOCKING whole-file CONTENT ceiling** — **bytes AND words, independently recomputed** (G-TARPIT-5),
   **whole-file, not per-surface** (a surface-scoped guard *displaces* growth — §A2). ~15 lines of CI. **Dumb
   on purpose.** Not atomicity (§A5), not a per-entry cap (§A4).
3. ❗ **A ceiling red is HUMAN-ONLY — the session STOPS.** It **MUST NOT** delete, compress, or strip to go
   green. *This single rule is what makes (2) safe instead of harmful (§A5-ter).* It reuses the repo's existing
   human-attestation pattern: **eviction from the eager index is a human judgment about which lesson is still
   load-bearing, and must never be automated.**

**Ceiling value: ~50 KB** (floor ≈ 46 KB + headroom) — ❗ and it **MUST be set AFTER the compressed draft
exists.** ❌ **The 33,400 B target was FICTION** — a sum of undrafted estimates, **10 KB below the last diet
that actually shipped (43,667 B) while carrying MORE content** (*"everything else" has itself grown +14,685 B
since the revamp, incl. 9,189 B of cross-model procedure that **G13 obliges the file to carry***).
*A ceiling derived from an undrafted estimate is how this change ships red on day one and stays red.*

**Sequencing (both reviewers converged):** **two stacked changes.** The **guard is implemented FIRST and
observed RED on the live 81,012 B file** — that red is the acceptance evidence, and it is obtainable **only**
if the guard precedes the diet. The diet then turns it green, and **only the green head merges.** ⚠️ Never
merge a blocking guard while the file is still over the line (it reds `main` and *normalizes tolerated red* —
the retry-tolerance class); ⚠️ never ship both as one change (the diet makes the guard green on day one and
**the guard is never observed to fail** — the F7 disease).

### A5-quinquies. ROUND 3 (convergence loop) — two ACCIDENT-class defects in the surviving design, and a measurement that reshapes it

**Protocol:** each reviewer was told *"you co-authored parts of this; you MUST NOT approve your own
contributions — mark them `MINE — not independently validated`"*, and to emit a mechanical
`VERDICT: NO OPEN ACTIONABLE | OPEN ACTIONABLE: <n>`, with **ADVERSARY-class findings explicitly NOT
actionable** (accepted residual R3) and an explicit instruction **not to manufacture objections to appear
rigorous**. ✅ **The self-exclusion held** — `gpt-5.6-sol` correctly disclaimed all four of its own
contributions rather than endorsing them.

**`gpt-5.6-sol` — `OPEN ACTIONABLE: 2`.** Both real, both ACCIDENT-class, both against the *loop-driver's*
adoption of the reviewers' own ideas:

1. ❗ **Merge-or-replace has NO PRESERVATION TEST — it relocates the caveat-strip rather than preventing it.**
   The admission test interrogates only the **new** line, and human judgment is reserved only for **ceiling**
   eviction. So *an honest merge can erase a qualification **before the ceiling ever fires***. **The harm the
   design was built to stop simply moved from ceiling-time to admission-time.** ⇒ Fix: every **displaced**
   prohibition / replacement / correctness-critical caveat MUST remain explicit; otherwise **append and
   escalate at the ceiling** instead of merging.
2. ❗ **The "guard observed RED on the live file" plan has NO SAFE EXECUTION SEAM in THIS repo.** CI runs on
   **push**, `main` is **unprotected**, and the maintainer **pushes directly with no PR flow** — so pushing
   the guard alone **reds `main`**, while pushing guard+diet together **only ever observes the green head**.
   **Neither path yields the red-on-the-real-corpus evidence the design depends on.** ⇒ Fix: a **locally
   runnable** checker whose red output is **recorded as evidence**, or an **awaited guard-only run on a
   non-`main` branch** before stacking the diet.

### A5-sexies. ❗ THE MEASUREMENT THAT RESHAPES THE DIET — fixing the tier is NOT enough

**Neither reviewer nor the loop-driver had computed this. DERIVED:**

| | bytes |
| --- | --- |
| tier now | **32,300** = 23 conforming bullets (15,598 B, **mean 678 B**) + **2 offenders (16,702 B)** |
| tier with the 2 offenders compressed to conforming size | **16,954** (saves 15,346) |
| **whole file after a TIER-ONLY fix** | ❗ **65,514** |

⇒ **A ~50 KB ceiling requires cutting ~12 KB MORE — out of the RULES sections** (OpenSpec workflow 17,660 B ·
How to work here 9,572 B · Building 7,656 B).

⚠️ **And that is dangerous ground: the 2026-07-06 ablation proved the REFUTATIONS tier load-bearing. The RULES
sections have NEVER been ablated.** Cutting 12 KB of them to satisfy a ceiling **is the compensating strip
(§A5-ter) one level up — except here the DESIGN ITSELF MANDATES IT.** *A ceiling that can only be met by
cutting un-ablated load-bearing rules is not a safe ceiling.*

### A5-septies. ❓ THE ESCAPE THAT MAY BEAT THE DIET — G13's premise is refuted, so procedures may be LAZY

**9,174 B** of the file is the **cross-model design-review procedure**. It is in `AGENTS.md` **only because
G13 holds that a rule must live in this file to reach the loop** (`⟶ archive-ritual` anchors to *"the
hand-authored committed procedure in this file"*).

❗ **But §A5-bis REFUTED G13's premise.** The leanness rule **did** reach the loop — from a **SHALL-grade
spec** and from **`xtty-capture-research/SKILL.md` at the point of action**. It was **overridden, not
unheard.** And **skill bodies are LAZY** (frontmatter at startup; body on invocation).

⇒ ❓ **Could the 9,174 B procedure live in a committed hand-authored `xtty-*` skill** — tracked, under our
control (which was the *original* objection to anchoring on the CLI-**generated** archive skill: `openspec
update` can rewrite it — a hand-authored `xtty-*` skill cannot be) — **with the `⟶` marker anchoring to it**,
removing **9 KB from the eager index with no loss of reach**? The marker stays either way; **only the ANCHOR
moves.**

**If it holds, this is a BIGGER LEVER THAN THE DIET** and it reframes the change from *"compress prose"* to
*"move procedures to the lazy tier; keep only decision-time content eager."* ⚠️ **NOT ADOPTED — under review.**
The open question is whether skill-body invocation is **reliable at the point a `⟶` marker is ticked** (a
marker is an *explicit* pointer, so invocation may be deterministic rather than the heuristic model-invocation
the docs decline to quantify).

### A5-octies. ❗❗ ROUND 4 — THE ENGINE IS DEAD: a "blocking CI ceiling" CANNOT BLOCK IN THIS REPO

**The single most important finding of the whole investigation, and it kills the mechanism every prior round
had assumed.** DERIVED:

```sh
git log --merges --oneline | wc -l                          # -> 0   (entire history)
gh api repos/kitimark/xtty/branches/main/protection         # -> 404 "Branch not protected"
gh api repos/kitimark/xtty/rulesets                         # -> []  (0 rulesets)
```

**ZERO merge commits in the repo's entire history. No PR flow has EVER existed. `main` is unprotected. CI runs
ON PUSH.**

⇒ ❗ **A CI ceiling cannot stop the write or the push. It is POST-HOC ADVISORY — i.e. the FOURTH advisory
surface, after the three that already failed (§A5-bis).** ***The design's own argument — "advisory has been
tried three times and lost three times" — applies to its own proposed mechanism.***

⇒ ❗ **And the ceiling + the human-STOP rule would jointly produce the design's OWN NAMED HARM as a STEADY
STATE:** on an honest overflow the STOP rule **forbids the model to fix it**, so **`main` stays red for the
entire human-latency window** and **every unrelated push during it is red** — ***"normalized tolerated red"***,
the retry-tolerance class this repo has **banned**. Not a rollout wrinkle: **the normal operating regime**
(eviction pressure bites in week one — §A5).

✅ **THE FIX — the only lane that fires BEFORE the write lands: a `PreToolUse` HOOK** on `Edit`/`Write`
against `AGENTS.md`, recomputing the content ceiling on the **proposed post-edit content** and **refusing the
edit**. **This actually blocks; CI cannot.** CI keeps the same checker as an honest **POST-HOC DETECTOR**
(it catches an out-of-harness human edit, or a bypassed hook) — **a detector, never "the gate."**
⚠️ **Surfaced dependency:** `.claude/settings.json` is **currently UNTRACKED** (`.gitignore:7` → `.claude/*`);
tracking it is a **deliberate one-line exception**, exactly the pattern already used for
`.claude/commands/xtty/`, `.claude/skills/xtty-*`, `.claude/agents/xtty-*`.
❗ **The hook had been DEFERRED on an untested assumption — THAT was the defect:** *deferring the unprobed,
strictly-better-positioned mechanism while shipping one that cannot block.* **The probe belongs IN the guard
change, not after it.**

### A5-nonies. ROUND 4 — three more ACCIDENT-class defects, all against the loop-driver

1. ❗ **MERGE-OR-REPLACE CONTRADICTS THE HUMAN-STOP RULE — and the meters go GREENER as it happens.**
   The STOP rule says eviction *"must never be automated"*; the admission rule **mandates the writing session
   perform merge-or-replace** — but **REPLACE *is* eviction** and **MERGE *is* compression**, both
   model-performed, both **routine** in a "fixed-size cache" that churns by design. An honest session merging
   two lessons drops the older one's qualification (*"HEDGED (n=1)"*, *"stated defeasibly"*) because **that is
   the cheapest merge** — §A5-ter's harm, **relocated from ceiling-time to admission-time**, where **the byte/word
   meters go GREENER, so the ceiling never fires and the human is never called.** *The design demoted the
   critic's semantic judgment and then installed a new mandatory write-time semantic judgment in its place.*
   ⇒ **Fix: a preservation test is necessary but NOT sufficient. A merge that would drop any existing entry's
   rejected-action / replacement / correctness-critical caveat is FORBIDDEN — the session APPENDS and escalates
   to the human. Model-performed merging is limited to the strictly LOSS-FREE case.**
2. ❗ **"The session STOPS" was under-specified — as written it DESTROYS what it protects.** A session blocked
   mid-capture had **no instruction for where the finding goes** ⇒ a fresh, expensive lesson survives only in a
   transcript, or the trackers are left half-reconciled. **The guard's first real firing would damage exactly
   the asset the tier exists to protect.** ⇒ **Fix (the parking spots already exist and are UNMETERED): on
   refusal the session MUST (1) complete every unmetered write — research doc, `HISTORY.md`, trackers;
   (2) record the pending eager-index admission as an EXPLICIT OPEN ITEM for the human; (3) stop ONLY the
   `AGENTS.md` append.** Nothing is lost; only the eager append is withheld.
3. ❗ **THE CEILING NUMBER IS STILL FICTION — the design committed v1's sin again at a different number.**
   *"~50 KB"* is **itself an undrafted estimate.** Corrected arithmetic (`gpt-5.6-sol` caught a **152 B** error
   in the loop-driver's sectional sum; the direct subtraction is authoritative):

   | scenario | floor |
   | --- | --- |
   | tier fix only — `81,012 − (32,300 − 16,954)` | **65,666 B** |
   | tier fix **+ the full 9,174 B procedure relocated** | **56,492 B** (before retained stubs) |
   | realistic, after a ~600–900 B stub | **≈ 57–60 KB** |
   | **50 KB** | ❗ requires **several KB of cuts to NEVER-ABLATED rules** — the compensating strip, **mandated by the design itself** |

   ⇒ ❗ **SET NO NUMBER UNTIL THE COMPRESSED DRAFT EXISTS. The ceiling is an OUTPUT of the diet, never an input.**

### A5-decies. ✅ THE RELOCATION LEVER — G13 is RELAXED, not refuted; and relocate PROCEDURES, never CONSTRAINTS

❌ **"G13 is refuted" was an OVERCLAIM.** Its **operative** content survives: the apply loop reads only the
**point-of-tick marker**, and the anchor must be **committed and not CLI-regenerable**. **The marker stays
either way — only the ANCHOR moves.** What falls is *only* the over-strong **"in this file"** clause (the
leanness rule reached the point of action **from a skill body** — overridden, not unheard; skill bodies are
lazy: of a 4,460 B skill only the ~616 B frontmatter is eager; a hand-authored tracked `xtty-*` skill is
neither machine-local nor CLI-generated).

❗ **THE DECISIVE CONSTRAINT — relocate PROCEDURES, never CONSTRAINTS.** *The very evidence that relaxes G13
also bounds it:* **the leanness rule reached the loop via a skill — AND LOST.** So **a skill-delivered
CONSTRAINT still loses to write-time pressure.** Relocation buys eager-token relief **only for checklists
executed at invocation**; it rescues **nothing** about admission control, the refutations tier, product values,
or delegation boundaries — **those are decision-time and MUST stay eager.** *Stating this asymmetry is what
stops the lever from becoming "move everything and hollow out the guide."*

⚠️ **Two blockers before any of the ~8.4 KB net moves:**
- **Split the procedure BY TRIGGER, not behind `⟶ archive-ritual` alone** — the **HUMAN-ONLY STOP task fires
  BEFORE the archive task** (`AGENTS.md:221-223`), so a single archive-time anchor **loses the earlier
  trigger.** ⇒ worker detail → `/xtty:cross-review`; **HUMAN-ONLY/STOP text → emitted into the attestation
  task itself**; archive checks → a committed `xtty-archive-ritual` skill.
- ❗ **The marker→skill hop has NEVER been observed here.** The measured marker evidence is for **agent-delegation**
  markers; *marker → model invokes `Skill` at tick* is plausible but **unproven**, and if it fails **nothing
  else routes there** (the openspec archive skill has **0** references to the gate). **The `fix-osc7`
  improvisation is what failure looks like.** ⇒ **Dogfood ONE real archive with the relocated anchor and verify
  BY EFFECT before deleting the eager text** (G-TARPIT-4).

### A5-undecies. ✅ THE CEILING IS A RATCHET, NOT A NUMBER — and the loop-driver double-counted

**Every fixed ceiling proposed in this investigation has been fiction, INCLUDING the corrected ones.** v1 said
33.4 KB. v2/v3 said *"~46 KB floor / ~50 KB ceiling"* — which requires *"everything else"* compressed to
**~31 KB, BELOW the revamp's measured 34,027 B while carrying +14,685 B MORE rule obligations, with no
compressed draft.** ❗ ***That is verbatim the crime the brief convicts v1 of, committed again at a new
number.*** *(Arithmetic also corrected: the tier-fix floor is **65,666 B** — the earlier 65,514 lost **152 B**
to section-boundary slop; conforming entries are **678 B**, not 632, so 25 entries ≈ **16.6 KB**; the procedure
is **9,174 B**, not 9,189.)*

> ✅ **THE FIX — the ceiling STARTS at what is MEASURED TODAY and only tightens as each cut is MEASURED to
> land. It is never an aspiration.**

| step | ceiling | requires |
| --- | --- | --- |
| **initial — adoptable TODAY** | **≈ 66 KB** | tier fix only. **ZERO un-ablated cuts.** |
| after the relocation lever validates | ≈ **57–58 KB** | one dogfooded archive proving the marker→skill hop |
| after the snapshot bound is enforced | ≈ **55–56 KB** | ✅ **enforcing the EXISTING SHALL — cutting nothing new** |
| **≤ 50 KB** | ⛔ **GATED** | a **RULES ablation** (extend the 2026-07-06 methodology) **or a recorded human acceptance** of un-ablated cuts |

**Why this is the right shape:** the guard can ship **today** — **red on the live file, green after the tier
fix, with ZERO risk to un-ablated rules** — and every further notch is **earned by a measurement**, never
asserted. *A ratchet cannot ship broken; a number can.*

### ⚠️ A5-duodecies. CORRECTION — the "12 KB of un-ablated RULES cuts" DANGER was OVERSTATED (double-counting)

1. ❗ **§A5-sexies' "~12 KB from the RULES sections" OVERLAPS the 9,174 B relocation candidate** — the
   cross-model procedure sits **INSIDE** the OpenSpec-workflow section's 17,660 B. **They were presented as
   independent quantities. They are not.**
2. ❗ **And it omitted the 3,393 B snapshot block.** Its *"Latest change:"* paragraph (~2.5 KB) is **per-change
   narrative in the status surface — which the ALREADY-COMMITTED write rule bounds** (`research-capture`'s SHALL
   + `SKILL.md`'s *"Narrative paragraphs never go here"*). **Compressing it ENFORCES AN EXISTING SHALL; it does
   not cut an un-ablated rule.**

⇒ **The residual un-ablated RULES cut needed to reach ~50 KB is ~4–6 KB, NOT 12 — and the 66 / 57 / 55 KB
waypoints need ZERO.** The compensating-strip danger is real **only below ~55 KB**, and the ratchet never goes
there without an explicit human decision.

### A5-terdecies. ❗ THE RELOCATION BOOKS GROSS AS NET — one clause has PROPOSE-TIME reach a skill cannot replace

**"9,174 B out with no loss of reach" is FALSE.** The obligation *"an in-scope change's `tasks.md` tail carries
exactly one blocking human-attestation cross-review task"* exists at **exactly ONE line in the eager surface**
(`AGENTS.md:221`) — **inside the block being moved** — and `openspec/config.yaml` carries **no** cross-review
rule. ❗ **A skill invoked at the ARCHIVE tick fires AFTER propose — far too late to EMIT the task.** *(Emission
is already this system's known-broken link — the abandoned `fix-cross-review-gate-task-emission`.)*
⇒ **A one-line eager stub MUST stay** (better: a `config.yaml` `rules.tasks` seed — that block already exists).
**Net saving ≈ 7.5–8.5 KB, not 9,174 B.**

**Three blockers before the diet math may BOOK it:** (1) **split by trigger** — worker detail → the
`/xtty:cross-review` command (❗ **a 13,943 B lazy near-twin ALREADY EXISTS there; the eager block partially
duplicates it today**), STOP text → the attestation task itself, archive checks → a committed
`xtty-archive-ritual` skill; (2) **dogfood ONE real archive through the relocated anchor** (the marker→skill hop
is **unproven**; the measured marker evidence is for *agent-delegation* markers, and if the hop fails **nothing
else routes there**) — ⚠️ **and the anchor must move WHOLE**, since `⟶ archive-ritual` today resolves to a
**composite spread across two `AGENTS.md` locations plus step-0**, and a split anchor re-opens the `fix-osc7`
improvisation class; (3) **probe skill-body STALENESS** — the adjacent measured hazard is same-session
**definition caching** (the agent-definition-lag refutation), **never tested for skill bodies**; a stale body is
a silently wrong procedure.

### A5-quaterdecies. ❗❗ ROUND 5 — THE HOOK ENGINE IS BROKEN TOO: a PreToolUse hook is TOOL-scoped, and the bloat came in through BASH

**The `PreToolUse` pivot (§A5-octies) was right that CI cannot block — and wrong about what can.** DERIVED:

- ❗ **Hooks match TOOL CALLS, not filesystem writes.** `Edit`/`Write` denial works (including inside
  subagents) — **but an ordinary `Bash` mutation bypasses it entirely.**
- ❗ **And the bloat DID come in through Bash. This is not hypothetical:** commit **`dca6b114`** — a
  `python3`-driven edit — grew `AGENTS.md` **59,404 → 61,684 B** (`git cat-file -s dca6b114^:AGENTS.md` vs
  `dca6b114:AGENTS.md`).
- ❗ **And every commit of THIS investigation was a Bash heredoc** (`python3 - <<'PY'`, `cat >>`). **A
  PreToolUse hook on `Edit`/`Write` would have seen NONE of them.**
- `CLAUDE.md` → `AGENTS.md` is a **symlink alias** that any file-matching rule must **canonicalize**.
- ⇒ **An honest session bypasses the gate ACCIDENTALLY, just by reaching for Bash.** **ACCIDENT-class ⇒ fatal.**

✅ **THE FIX — measure the FILE, not the TOOL: the gate is a `Stop` HOOK.**
A `Stop` hook is **file-scoped and tool-agnostic** — it re-measures `AGENTS.md` at session end **regardless of
how the bytes got there**, so it **cannot be bypassed by choosing a different tool**. *(The primitive is
proven: this repo's own `/goal` command is a Stop hook, and it blocks.)* `PreToolUse` on `Edit`/`Write` is
retained only as an **early, friendlier warning** — never as the gate.

### A5-quindecies. ROUND 5 — three more ACCIDENT-class defects

1. ❗ **HOOK FAILURES ARE FAIL-OPEN.** Claude blocks **only on exit 2**; **any other nonzero exit lets the tool
   call proceed.** A missing checker, a malformed input, a dependency failure, a timeout, or **invalid project
   settings (silently ignored under `-p`)** therefore **REMOVES THE GATE.** ⇒ **Every failure path MUST be
   converted to an explicit denial (exit 2), and that must be REGRESSION-TESTED.** *A gate that fails open is
   not a gate — and this is the same class as F7 (a "fail-closed" property that was never enforced).*
2. ❗ **THE CEILING DEADLOCKS ITS OWN DIET.** The file is **81,012 B**; the initial ratchet ceiling is
   **~66 KB**. Under a blocking hook, **every intermediate edit whose result is still above 66 KB is REFUSED**
   — so the file **cannot be dieted incrementally at all.** The design therefore **silently requires a one-shot
   rewrite, or the very Bash bypass it is trying to close.** ⇒ **Fix: bootstrap semantics — while over budget,
   PERMIT any STRICTLY DECREASING edit** (or activate the gate only once the diet is green).
3. ❗ **"Relocate PROCEDURES, never CONSTRAINTS" COLLAPSES AT THE CHOSEN RELOCATION.** `AGENTS.md:223`'s **four
   archive-refusal checks ARE eligibility CONSTRAINTS**, yet the design sent *"archive checks"* into an
   **invocation-dependent skill**. **One successful dogfood proves possibility, not reliable routing** — an
   accidentally missed or stale skill invocation **removes the constraint**. ⇒ **Keep the refusal INVARIANT
   eager and complete; lazy-load only its EXECUTION MECHANICS.**

### A5-sexdecies. ✅ ROUND 5 CONVERGENCE — the gate is **GATE THE PUSH**, and the brief itself caught the disease

**Both reviewers independently found the Bash lane** (a genuine convergence *on a defect* — the only kind that
counts). fable-5 added three the other missed:

1. ❗ **The `CLAUDE.md` symlink alias.** An `Edit`/`Write` addressed to **`CLAUDE.md`** changes identical
   content, but `tool_input.file_path` contains **no "AGENTS.md"** — a predicate keyed to one basename misses
   it. **Match both names; resolve the link.**
2. ❗ **HOOKS CAN SILENTLY NOT FIRE.** Project `.claude/settings.json` hooks **require workspace trust — until
   accepted they do not run, silently**; `disableAllHooks` also silently disables. *"It blocks"* is
   **conditional on delivery** — ❗ **this repo's own measured failure class** (the `Definition:`-stamp lesson:
   *verify delivery, never assume*). ⇒ **a liveness probe is mandatory.**
3. ❗ **The parked admission had NO NAMED SURFACE.** *"Record it as an open item for the human"* names no
   tracked file ⇒ it can evaporate into the transcript — and this repo has **measured** that unanchored
   procedure steps get improvised (**that is how G13 was born**). ⇒ **Name it: the active change's `tasks.md`,
   or a designated `HISTORY.md` block.**

✅ **THE GATE — `GATE THE PUSH`.** *Every write path — `Edit`, `Write`, `sed`, `python3`, a subagent,
`git apply` — converges on `git push`.* ⇒ **`PreToolUse` on `Bash` matching `git push`, re-measuring the file
ON DISK and refusing the push.** **File-scoped in effect ⇒ immune to the tool-choice bypass.** Layered with an
`Edit`/`Write` early warning (bypassable, not the gate), a **`Stop`-hook backstop** (file-scoped, tool-agnostic
— the primitive is proven: `/goal` is a Stop hook), and **CI as an honest post-hoc detector**.

### A5-septendecies. ⚖️ ADJUDICATED — the reviewers SPLIT, and both were half right

`gpt-5.6-sol` said *"relocate PROCEDURES, never CONSTRAINTS"* **collapses** (the four archive-refusal checks
**are** constraints, and a missed skill invocation removes them). `fable-5` said it **holds** (the operative
sentence keys on **trigger-time**, so the naming is a proxy) — **and correctly flagged it as its own
contribution, asking a non-participant to re-check.**

⚖️ **Non-participant adjudication:** *"procedures vs constraints"* is a **bad proxy** — the refusal checks are
constraint-shaped yet execute at a known invocation point (fable is right). **But a constraint whose
enforcement depends on a HEURISTIC INVOCATION is strictly weaker than an eager one** (gpt is right).
⇒ **Synthesis: keep each refusal INVARIANT eager and complete (one line — *what must be true*); lazy-load only
its EXECUTION MECHANICS (*how to check it*).** Both constraints satisfied.

### A5-duodevicies. ❗ THE BRIEF ITSELF CAUGHT THE DISEASE — a self-demonstration

By round 5 the design brief had grown to **28,647 B of layered corrections**, and had gone **internally
inconsistent**: §2 still asserted the *"~46 KB floor"* and *"12 KB from the RULES sections"* that §4 had
already refuted; a stale **65,514** sat beside the corrected **65,666**; §2c's heading said *"refuted"* while
its body said *"relaxed"*. `gpt-5.6-sol` reported the contradictions as a finding.

❗ **The cause was exactly the mechanism under investigation: every correction was APPENDED, and the thing it
corrected was never EVICTED.** The fix was the same one the design prescribes: **a clean rewrite with the dead
ideas quarantined into an explicit "do not re-propose" table**, not another patch.

> **A document that records its own corrections by accretion will always drift into self-contradiction. This
> is not a metaphor for the AGENTS.md problem — it is the same failure, observed live, in the artifact
> arguing about it.**

### A5-undevicies. ✅✅ ROUND 6 — THE ANSWER: a GIT `pre-push` HOOK. Three engines died; this one is at the right layer.

**Engine #3 (a Claude `PreToolUse` hook on `Bash` matching `git push`) is DEAD too — ACCIDENT-class.** DERIVED:
Claude Code's `matcher` filters the **tool name**; `Bash(git push *)` is a **best-effort permission filter, not
a regex over the command string**. Honest forms that MISS it: `git -C "$PWD" push` · `/usr/bin/git push` ·
`make publish` · a wrapper script · `gh` · a GitHub MCP push.

> ❗ ***"The actual convergence point is a Git `pre-push` hook."*** — and `--no-verify` is then **ADVERSARY/R3,
> an ACCEPTED residual.**

✅ **ENGINE #4 — a tracked `.githooks/pre-push` + `git config core.hooksPath .githooks` ($0, two lines).**
**Why this one is finally right, where three others were wrong:**

| property | CI | PreToolUse(Edit/Write) | PreToolUse(Bash: git push) | ✅ **git pre-push** |
| --- | --- | --- | --- | --- |
| can it block? | ❌ post-hoc (0 merge commits ever) | ✅ | ✅ | ✅ |
| survives a **Bash** write? | ✅ | ❌ **the bloat came in this way** | ✅ | ✅ |
| survives `git -C` / `make` / `gh` / MCP push? | ✅ | — | ❌ | ✅ **below the agent** |
| silent-non-fire lane? | — | ⚠️ workspace trust | ⚠️ workspace trust | ✅ **none** |
| bypass class | — | ACCIDENT | ACCIDENT | ✅ **`--no-verify` = R3, accepted** |

❗ **AND IT FIXES A HOLE NOBODY HAD SEEN — THE MEASUREMENT TARGET WAS WRONG.** `git push` transmits
**COMMITTED OBJECTS**; `wc AGENTS.md` measures the **WORKING TREE**. ⇒ **An honest session with a RED committed
`AGENTS.md` and a GREEN uncommitted diet would have the gate approve the disk while pushing the red commit.**
A real `pre-push` hook **receives the local/remote OIDs** and must inspect **`git show "$local_oid:AGENTS.md"`**
— the actual bytes going to the remote. *(Also: a `Stop` hook is a weak backstop — it fires only **after** Claude
finishes responding, i.e. **after** the remote mutation, does **not** fire on interruption, and Claude Code
**overrides it after 8 consecutive blocks**.)*

### A5-vicies. ❗ THE METER DOES NOT MEASURE THE OBJECTIVE — bytes/words are a PROXY that can move the WRONG WAY

**The objective is STARTUP TOKENS. The ratchet counts BYTES and WORDS. They are not monotonic.** A rewrite can
**reduce both while INCREASING** the subword-token count — dense identifiers, hashes, paths, punctuation.
Measured demonstration:

```
"the " x100        -> 400 B / 100 words
300-char hex blob  -> 300 B /   1 word
```

⇒ **The ratchet would see "improvement" and never observe tokens.** *(This file already tokenizes at **2.46
bytes/token**, ~40% denser than prose — it is ALREADY in the regime where the proxy misleads.)*

✅ **Fix — the instrument already exists, committed:**
`openspec/changes/archive/2026-07-06-slim-agents-context/probes/measure-context.sh`. ⇒ **Either add a stable
token metric to the ratchet, or explicitly NARROW the ratchet's claim to a bytes/words proxy AND retain a
recurring token-cost acceptance check.** *A guard whose meter is not monotone with its objective can be
satisfied while the objective regresses.*

### A5-vicies-semel. ✅ ROUND 6 CONVERGENCE — both models found the SAME two defects independently; the design is now being REFINED, not killed

**Convergence ON DEFECTS (the only kind that counts):** both reviewers independently found **(a)** the
command-string matcher is unreliable and **(b)** the checker was measuring the **wrong object**. Neither
authored the other's finding.

**fable-5 pushed (b) further than gpt did, and found the freeze:**

❗ **THE RATCHET'S COMPARATOR HAD NO DEFINED BASELINE — and the obvious reading FREEZES THE REPO.**
*"Permit only strictly-decreasing edits while over budget"* is **uncomputable from a snapshot**: *decreasing
relative to what?* **The gate sees a PUSH, not an edit.** During the **mandated** guard-red window (81 KB file,
66 KB ceiling), **an untouched file is not "strictly decreasing"** ⇒ **every unrelated push is refused.**
***The CI-red disease, re-imported through the hook — and the brief's own wording invited that
implementation.***

✅ **THE CORRECT COMPARATOR:**
> **current** = the pushed ref's blob · **baseline** = `origin/main:AGENTS.md`
> **while OVER the ceiling: refuse iff `current > baseline`** *(a shrinking or unchanged push always passes ⇒
> the diet is always permitted and unrelated work is never frozen)* · **once UNDER: refuse iff
> `current > ceiling`.**

**And two more:**
- ❗ **The mutation suite had ZERO push-variant fixtures — the design FAILED ITS OWN RULE** (*"a guard never
  demonstrated to fail is not a guard"*). ⇒ add `git -C <abs> push`, `git -c k=v push`, `cd x && git push`,
  env-prefixed, heredoc-embedded, a **fat-commit-from-a-clean-looking-dirty-tree**, **and a NEGATIVE fixture**
  (an unrelated push during the red window MUST pass — proving no freeze).
- ✅ **BIAS THE MATCHER BROAD — the asymmetry is free.** An **over-match costs nothing** (the hook refuses only
  on a *measured breach*, so a heredoc merely *mentioning* `git push` measures and passes); an **under-match is
  fatal.** *(Also DERIVED: the Makefile/alias lanes are **closed** in this repo — `grep -n push Makefile
  scripts/*.sh` → empty; `git config --get-regexp '^alias'` → empty — leaving `-C`/`-c` forms and wrapper
  indirection as the live misses.)*
- **The `Stop` backstop deadlocks** if given a bare over-ceiling test (stop-standoff until `stop_hook_active`
  degrades it to noise) ⇒ it **must** use the same growth-vs-baseline comparator, honor `stop_hook_active`, and
  state a remediation message. **Honest limits:** it fires **after** the response completes (a mid-session push
  is already published) and a **killed session skips it entirely** ⇒ the CI lane.

### ⚖️ A5-vicies-bis. THE SYNTHESIS NEITHER MODEL HAD

**`gpt-5.6-sol`'s git `pre-push` hook DISSOLVES `fable-5`'s matcher problem — for the GATE.** Git fires
`pre-push` **regardless** of `git -C`, `git -c`, an alias, a wrapper script, `make`, or `gh`. **The matcher
concern survives only for the ADVISORY arm**, where over-matching is free.

⇒ **The honest layering, with each layer's real job stated:**

| layer | mechanism | job | escapes |
| --- | --- | --- | --- |
| ✅ **GATE** | tracked **`.githooks/pre-push`** + `core.hooksPath` | **refuse the push**, measuring `git show "$local_oid:AGENTS.md"` | **`--no-verify` ⇒ R3 (accepted)**; pushes that never touch local git |
| early warning | `PreToolUse` (broad matcher) | fail fast + friendly | wrapper indirection — **accepted in writing** |
| backstop | `Stop` hook (same comparator) | same-session remediation | mid-session pushes; killed sessions |
| detector | CI | post-hoc truth | nothing — but it cannot block |

❗ **The "immune to the tool-choice bypass" headline needed a carve-out, and now has one.**

### A5-vicies-ter. ❗❗ ROUND 7 — TWO OF MY OWN FIXES COLLIDED AND CANCELLED. Neither was wrong.

**The single most instructive finding of the whole investigation, and it is about the REVIEW PROCESS, not the
design.**

- **Round 3** established: *"a guard never observed to fail is not a guard"* ⇒ acceptance = **observe the guard
  RED on the live 81 KB file.**
- **Round 6** established: the comparator must be **growth-vs-baseline**, not absolute-ceiling-while-over —
  otherwise the guard **freezes the repo** during the mandated red window.

**Both fixes are correct. Together they CANCEL.** DERIVED:

```
HEAD == origin/main == 8e626a93c00e
HEAD:AGENTS.md = 81,012 B   origin/main:AGENTS.md = 81,012 B
comparator: refuse iff current(81012) > baseline(81012)  ->  FALSE  ->  GREEN
```

⇒ ❗ **The guard is GREEN on the very file that motivated it, and the round-3 acceptance evidence CANNOT
FIRE.** *A change that had shipped both fixes would have claimed "the guard was observed red on the live file"
— and it would have been impossible.*

✅ **Fix:** the RED evidence must be **a COMMITTED POSITIVE MUTATION that exceeds the baseline** (not the
unchanged live file), **and** the unchanged-file **NEGATIVE** fixture must be retained (proving no freeze).
**The two fixtures together are the acceptance test; either alone is a lie.**

> 🔑 **GUIDELINE — In an iterated review, each fix is validated against the design AS IT WAS, never against the
> design AS IT WILL BE. Two independently-correct fixes can silently cancel.** *The only defence is a fresh
> adversarial read of the WHOLE artifact after the fixes land — which is exactly what caught this. **This is
> the strongest argument in the entire investigation for a final full-artifact review pass, as opposed to
> iterating patch-by-patch.***

### A5-vicies-quater. ROUND 7 — four more ACCIDENT-class defects in the git-hook engine

1. ❗ **A TRACKED HOOK IS INERT IN EVERY FRESH CLONE.** DERIVED: `git config --get core.hooksPath` → **UNSET**;
   `.git/hooks/pre-push` → **ABSENT**. ***`.git/config` is NOT CLONED*** ⇒ **a fresh clone (or a new machine, or
   CI) silently ships with NO GATE.** ⇒ **The "silent non-fire lane: none" claim was FALSE — the git hook has
   one too, just a different one.** ✅ **Fix: make it SELF-INSTALLING** (`make setup` already exists,
   `Makefile:71` — add `git config core.hooksPath .githooks`), **and make CI verify the hook is installed**
   (the detector for the silently-absent lane). **Acceptance MUST test a genuinely fresh clone.**
2. ❗ **`origin/main` IS THE WRONG BASELINE — it is a CACHED, NON-REF-ATTRIBUTIVE ref.** The `pre-push` hook
   **receives the AUTHORITATIVE `$remote_oid` on stdin** and the design **ignored it.** A stale clone can push a
   branch that exceeds **both its base and the ceiling** while measuring **below** a stale, oversized
   `origin/main`: *(base 43,667 · ceiling 65,666 · current 80,000 · cached `origin/main` 81,012 ⇒ **PASSES**)*.
   ⇒ **Use `$remote_oid` per pushed ref. A first push (all-zero `$remote_oid`) needs an explicitly defined
   base.**
3. ❗ **DELETION PUSHES BREAK THE BLOB LOOKUP.** Git supplies an **all-zero `$local_oid`** for a deletion;
   `git show 000…0:AGENTS.md` **exits 128** ⇒ **fail-closed handling would block ordinary branch/tag deletion.**
   ⇒ **Add an explicit deletion case and a fixture.**
4. **The bypass list was too narrow.** Not only `--no-verify`: also **`git -c core.hooksPath=/dev/null push`**,
   removing the hook, and direct plumbing/API pushes. **All the same accepted R3 trust class** — but say so.

### A6-pre. ❗ CORRECTION (probe, 2026-07-13) — there IS a decision-time channel, and §A6 below missed it

§A6's table concluded *"the refutations cannot be relocated; compression is the only lever."* **That
conclusion is now PARTIALLY REFUTED** — and §A6's rejection of `.claude/rules/` was resting on an **untested
assumption** that has now been **probed against the official docs**.

| claim | status after the probe |
| --- | --- |
| path-scoped `.claude/rules/` cannot carry decision-time guidance | ✅ **CONFIRMED, and now docs-sourced** — *"Path-scoped rules trigger when Claude **READS** files matching the pattern, not on every tool use."* They load **after** the decision to write. *(It was rejected on an assumption; it is now settled.)* |
| nested `CLAUDE.md` | ✅ confirmed read-triggered — same timing failure |
| `@path` imports | ✅ confirmed **eager** — save nothing |
| **"no lazy tier can deliver decision-time rules"** | ❌ **REFUTED — the `UserPromptSubmit` HOOK** |

❗ **`UserPromptSubmit` fires BEFORE the model reasons**, and its `additionalContext` output **injects text into
context at prompt time** — a **deterministic, documented, decision-time channel** that costs **zero at startup**.

⚠️ **But it is a LANE, not a fix — and it must be probed before anyone proposes it:**
- **Cost may INVERT.** The eager guide is loaded **once and cached**; a hook injects **per prompt**. An
  unconditional hook that emits the whole tier every turn could cost **more** than the thing it replaces.
- ⇒ it only pays if **conditional** — and a condition is a **keyword heuristic**, which fails in exactly the
  case the tier exists for: ❗ **a session about to re-propose the Metal renderer may never type "Metal."**
  *A decision-time rule that fires on keywords misses the decision that does not name itself.*
- **Subagent coverage is UNKNOWN** (subagents inherit `CLAUDE.md`; whether a `UserPromptSubmit` hook fires for
  them is undocumented). The eager tier's whole value multiplies across subagents.
- Model-invoked **skills** are the other candidate and are **heuristic, with no published reliability
  metrics** — the docs say Claude *"decides when to apply"*, and quantify nothing.

**Re-verify by effect (NOT YET RUN — do not adopt this lane from a doc):** write a trivial `UserPromptSubmit`
hook emitting a unique marker string; then (1) `/context` before/after to price it, (2) spawn a subagent and
have it quote the marker **without tools** (the same presence probe that proved `CLAUDE.md` subagent
inheritance) to settle coverage.

### A6. Lazy tiers — the standard's one real mechanism, and why it CANNOT hold the refutations
*(⚠️ superseded in part by §A6-pre: the "compression is the only lever" conclusion is refuted; the
read-triggered rejections below are confirmed.)*

The published `agents.md` convention specifies **no required fields, no structure, no length guidance**
(*"just standard Markdown — use any headings you like"*). xtty already conforms; **"conform to the standard"
is vacuous as an optimization target.** Its one real mechanism is nesting. Verified against Claude Code's
own docs:

| mechanism | startup cost | verdict for xtty |
| --- | --- | --- |
| root `CLAUDE.md` (symlink → `AGENTS.md`) | **eager, in full**; inherited by every subagent | the problem |
| `@path` imports | ❌ **EAGER** — *"expanded and loaded into context at launch"* | **saves nothing** |
| nested `CLAUDE.md` | ✅ **lazy** — *"included when Claude reads files in those subdirectories"* | ❌ rejected (rec 6 stands): must be named **`CLAUDE.md`** — a nested **`AGENTS.md` is silently ignored**; measured candidate `packer/` = **743 B** |
| `.claude/rules/*.md` + `paths:` | ✅ lazy (fires on reading a matching file) | ❌ **structurally wrong for refutations** — see below. (Also gitignored today, but that is a 2-line negation, not the real objection.) |
| Skills | frontmatter eager, body lazy | ✅ already used; right for **procedures**, not for decision-time rules |

❗ **The load-bearing argument, and it kills the most attractive option:** **refutations are DECISION-time, not
file-read-time.** *"Don't re-propose the Metal renderer"* must be in context when you are **proposing** — which
happens **before any file is read**. A path-scoped rule fires on a file read that never comes.
⇒ **The refutations tier cannot be lazily loaded, by construction. Its only lever is compression.**
(This also **corrects §3's framing**: `.claude/rules/` is not a dead end because of gitignore — it is a dead
end for *this tier* because of **when** it fires.)

### A7. Correctness defects found en route (independent of any diet)

1. ⚠️ **`openspec/config.yaml:11` still asserts *"Renderer: custom Metal view (MTKView/CAMetalLayer), …
   dedicated render thread"*** — flatly contradicting the settled Metal refutation and the closed P7b gate,
   and it is **injected into the AI on every artifact creation**. Live defect; two-line fix.
2. The **F10 retirement is carried twice** (AGENTS.md L15 + L66); the classifier's latch/non-attributive
   mechanism **three times** (L15, L66, L217).
3. The pairing-consult bullet numbers **two different findings "(11)"**.
4. `grep -c 'G-CONSULT' HISTORY.md` → **0** — the file's **second-largest bullet** (7,048 B) never received the
   HISTORY narrative that the *"Keep progress current"* rule requires. **The anti-bloat rule was violated by
   the very session writing the bullet about rules that don't hold** — which is the mechanism, not an irony:
   nothing was watching.

### A8. Fates table (this addendum)

| Claim | Fate | Killed / confirmed by |
| --- | --- | --- |
| "A second diet without a guard will regrow just as fast" (rec 9) | ✅ **CONFIRMED** | 43,667 → 81,012 in 48 h |
| "Enforcement = critic heuristic **vs.** byte gate" (this doc's open question) | ❌ **RETIRED — wrong question** | the heuristic **shipped and held** (Tooling row 1,934 B) and the file **doubled anyway**: surface-scoped guards **displace** growth |
| "A per-unit word cap is compression-proof" | ❌ **REFUTED (ACCIDENT-class)** | `gpt-5.6-sol`: split the entry into 24 short bullets — passes lint, keeps the cost |
| "The bloat is distributed drift; cap the length" | ❌ **REFUTED** | atomicity census: **2 of 25** entries hold **54.5%** of the tier; the other 23 are already correct |
| "`.claude/rules/` is a dead end because it's gitignored" (§3) | ⚠️ **CORRECTED** | gitignore is a 2-line fix; the **real** blocker is that refutations fire at **decision** time, not file-read time |
| "Conform to the AGENTS.md standard" (the framing that started this) | ❌ **VACUOUS** | the standard specifies no fields, no structure, no length |
| "The refutations tier can be moved out of the eager index" | ❌ **REFUTED** | decision-time ⇒ no lazy tier can deliver it |

### A9. Re-verify by effect

The change this addendum feeds **does not succeed by shrinking the file** — that has been achieved twice and
proved nothing. ***"Size-only green is insufficient."*** Re-verify:

1. **MUTATION-TEST THE GUARD** (the F7 lesson applied to itself): feed it (a) a fat entry **split into N short
   bullets**, (b) rationale **overflowed into adjacent prose / extra rows**, (c) an entry with **inline numbered
   sub-findings**. **It must go RED on all three.** *A guard never demonstrated to fail on a real bypass is not
   a guard.*
2. **Blinded long-vs-short A/B**, all 25 conclusions + pointers held constant, against the committed
   pre-registered rubric. **Fails if the compact, guard-green version scores WORSE on the trap/adherence
   probes.** ❗ Note this tests the axis the 2026-07-06 ablation **never** did — that one tested
   **presence vs. absence**, never **long vs. short**, so *nothing measured supports the long form either*.
3. `claude -p` startup-token instrument: the drop must appear (baseline today: **57,569**).
4. **One week after the change lands, re-run the §1b growth loop.** If the growth rate is still ≥8.8 KB/day,
   the guard is cosmetic and the change **failed** — regardless of how small the file looked on merge day.

### A10. Reusable guideline (extends §7)

6. **A surface-scoped guard displaces growth to the next unguarded surface.** Measured here: the shipped
   category-keyed critic bound **held its row** while the file **doubled** into a different tier. Guard the
   **admission rule** (what kind of content may enter), not the **size of a surface** — otherwise every fix
   buys one surface and one release cycle.
7. **Length is the wrong invariant for a curated index; ATOMICITY is the right one.** A length cap is
   satisfiable by splitting (accident-class), by deleting the caveats that make a rule *correct*, and by
   evicting old load-bearing entries. *"One entry = one rejected action + replacement + pointer"* is
   satisfiable **only** by moving the mechanism to where it belongs.
8. **Before proposing a fix for a recurring problem, `grep research/` for the prior fix.** This file had been
   dieted **twice** and studied **twice**; the session that opened this addendum did not know the 2026-07-10
   study existed until a subagent cited it. **The prescription was already written, and ignored.**
