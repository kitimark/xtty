## 1. Un-ignore the workflow tooling

- [x] 1.1 Edit `.gitignore`: add `!.claude/commands/opsx/` beside `!.claude/commands/xtty/`, and `!.claude/skills/openspec-*/` beside `!.claude/skills/xtty-*/`, keeping the existing level-by-level style (D1).
- [x] 1.2 Rewrite the leading `.gitignore` comment block (lines 1–4) that currently says the openspec-generated commands/skills "stay out of git" — describe the new policy (opsx/openspec-* are tracked + CLI-version-pinned; only `settings.local.json` + locks stay ignored).
- [x] 1.3 Stage the tooling: `git add .claude/commands/opsx .claude/skills/openspec-*` so the 8 `opsx/*.md` + 8 `openspec-*/SKILL.md` files enter tracking.

## 2. Reconcile AGENTS.md to the new policy

- [x] 2.1 Update the Conventions "Don't track local tooling" bullet: add `opsx`/`openspec-*` to the committed set and state the drift policy (regenerate via `openspec init`/`update` and re-commit deliberately on a `generatedBy` bump; routine `list`/`validate`/`status` don't rewrite them).
- [x] 2.2 Reframe (a *reasoning* rewrite, not a word-swap) the three archive-ritual passages that justify the `⟶ archive-ritual` marker by calling `/openspec-archive-change` "gitignored"/"uncommitted" — confirmed to be exactly lines 52, 146, 193 (grep of the broken predicate; 91/111 are unrelated `gitignored` matches). Keep the anchor-to-the-committed-hand-authored-procedure conclusion; replace the now-false reason with the durable one (even committed, the CLI-generated skill can be rewritten by `init`/`update`, so the hand-authored procedure stays the stable anchor) (D4). Two clauses actually invert and must be rewritten, not deleted: **line 52** *"a committed task can't depend on an uncommitted tool"* (premise now false) and **line 146** *"optional local accelerator **when present**"* (a committed skill is always present). Line 52 is the **G13** Learned-refutation — preserve it as a still-valid refutation with corrected reasoning, don't leave a half-swapped sentence.

## 3. Verify by effect (git tracking resolution — D5)

- [x] 3.1 Assert the tooling is now tracked: `git check-ignore -v` returns nothing for `.claude/commands/opsx/apply.md` and `.claude/skills/openspec-apply-change/SKILL.md`, and all 16 files are present in the index (`git ls-files` lists them — the `git add --dry-run` proof was pre-empted by staging them in 1.3, so index membership is the equivalent assertion).
- [x] 3.2 Assert machine-local files stay ignored: `git check-ignore -v .claude/settings.local.json .claude/scheduled_tasks.lock` still reports them ignored by `.claude/*`.
- [x] 3.3 Confirm no accidental app/runtime surface changed: the diff touches only `.gitignore`, `AGENTS.md`, `openspec/**`, and the newly-tracked `.claude/**` tooling files (no source, no `project.yml`).

## 4. Land the change

- [x] 4.1 Commit: the un-ignore + AGENTS.md reconcile under an appropriate scope (e.g. `chore(openspec): track generated opsx/openspec-* workflow tooling`), plus the openspec artifacts under `docs(openspec):`.
- [x] 4.2 Pre-archive coherence review ⟶ xtty-openspec-critic (track-openspec-workflow-tooling) — spec-delta format, the proposal↔specs contract, the archive-ritual reframing coherence, and disk-drift. VERDICT: COHERENT (2 informational REVIEW notes, both about the archive-reconcile step below; no blockers).
- [x] 4.3 Archive + reconcile ⟶ archive-ritual — `openspec archive track-openspec-workflow-tooling`, finish the `build-workflow` merge by hand (fill Purpose if needed, make merged text reflect what shipped, `openspec validate --all --type spec`), reconcile the trackers (AGENTS.md Current-status row/snapshot as applicable, HISTORY.md narrative, milestone state if moved), and verify against disk (`openspec list`, `ls openspec/changes/archive/`, `ls openspec/specs/`). DONE: merged (build-workflow 14→15, 23/23 specs valid, text reflects what shipped — no divergence); trackers reconciled (open-changes table already matched; snapshot "Latest change" + HISTORY narrative updated; Tooling row left unchanged — folds into its existing "guide structure" category without a row edit, per the critic heuristic; no milestone/refutation entry); verified against disk (active={add-ci-pipeline}, archive dir present, 22 specs unchanged).
