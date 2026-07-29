## 1. Design-system package (`design/xtty/`)

> Drafted ahead of this proposal and parked in `git stash` (`design/xtty/{tokens.css,manifest.json,metadata.json}`, `scripts/design-link.sh`, the Makefile targets — see `git stash list`); restore it when applying. These tasks verify and finish that draft rather than starting from nothing. Raw material for the prose: the recovered prior draft at `/tmp/od-poc-salvage/recovered/` (scratch; will not survive a reboot).

- [x] 1.1 `tokens.css` — bind all 56 schema tokens plus namespaced `--xtty-*` extensions, each declaration carrying an `M`/`P`/`D` provenance tag per design.md D3
- [x] 1.2 Verify token coverage mechanically: every schema name present, no unprefixed non-schema name (a diff against `packages/contracts/src/design-systems/token-schema.ts`)
- [x] 1.3 Re-verify every `M`-tagged value against current xtty source at HEAD — flag any drift from the values the prior draft carried, and correct rather than inherit
- [x] 1.4 `manifest.json` — id, files map, and a `source.origin` recording that no importer can regenerate this package
- [x] 1.5 `metadata.json` — the app's own 9-key set minus the key it supplies, with `status: "published"` and `artifactMode: "agent-managed"` (design.md D6)
- [x] 1.6 `DESIGN.md` — 9 sections; the colour-palette section authored to the swatch extractor's literal shape (bare labels, flat hex immediately after the bold label, no earlier line naming a background/surface/canvas)
- [x] 1.7 Probe the authored `DESIGN.md` against a port of the swatch extractor (`design-systems/index.ts:3775-3865`) — expect the four intended values and all slots filled. **The failure is silent; do not skip.**
- [x] 1.8 `USAGE.md` — the rules expected to iterate, since this file stays fresh through the symlink while `DESIGN.md` does not

## 2. Project folder and repository policy

- [x] 2.1 `design/.gitignore` — per-entry annotated rules, placed one level above the agent's working directory (design.md D5)
- [x] 2.2 `design/mockups/README.md` — the project brief the design agent reads, including the baseline-first instruction and the never-touch list
- [x] 2.3 `design/mockups/index.html` — hand-authored gallery shell, zero JS, pinning entry-file detection; cards added per accepted scenario
- [x] 2.4 `design/README.md` — the human contract: the two halves, the naming contract, the promote-and-delete ritual, the per-machine vs portable split, the update lifecycle including the design-document cache freeze, and the safety posture with its post-run checklist
- [x] 2.5 Confirm the ignore rules classify correctly against a real run's output — and that any marker hidden by a rule is covered by an explicit existence test in the checklist

## 3. Linkage tooling

- [x] 3.1 `scripts/design-link.sh` — register by symlink, idempotent, stale-link repair, by-effect verification, status and by-hand uninstall modes, and a printed list of what remains human-only
- [x] 3.2 Confirm the script is committed executable (`git ls-files -s` shows mode `100755`) — the Makefile recipes invoke it directly
- [x] 3.3 `Makefile` — `design-link`, `design-status`, `design-unlink` targets with `##` descriptions, added to `.PHONY`; `design-status` prefixed so an unlinked repo does not read as a build failure
- [x] 3.4 Verify `make` with no target lists all three new entry points with their descriptions (the self-documenting requirement)
- [x] 3.5 Verify the not-running path: with the design tool quit, the linkage command fails naming that cause and does not attempt to launch it — and `make design-status` reports the state as indeterminate (cannot-determine), not as "not linked"
- [x] 3.6 `--create-project` (also auto-run from install): dedupe-first by `realpath(baseDir)` via the shared matcher, creation through the app's bundled first-party CLI (Electron helper as interpreter; IPC socket located from public process metadata only — no hand-minted tokens, gate satisfied not bypassed), by-effect verification (folder-backed shape + `fromTrustedPicker` + zero bytes written into `design/`), chained design-system + platform configuration, manual-GUI fallback on any failure
- [x] 3.7 Reconcile every artifact that asserted project creation was GUI-only (`design/README.md`, `design.md` D8/Non-Goals/Open Questions/Risks, the script's install banner, `specs/build-workflow/spec.md`), and record the `fromTrustedPicker` semantics shift plus the two measured hazards (no dedupe on folder import; API/CLI delete leaves a phantom UI card until relaunch)

## 4. Live linkage and verification

- [x] 4.1 Commit the package and tooling before linking — the symlink must resolve a committed directory, and a clean pushed tree is the precondition for any agent run
- [x] 4.2 Run `make design-link` against the running app; confirm from its output the link resolves to the repo path, the catalogue reports the package published, and token coverage is complete
- [x] 4.3 Create the project in the app (human step — native folder picker at `design/mockups/`), then verify the import wrote zero bytes into the repo
- [x] 4.4 Set the project's design system to the xtty package (human step), then verify the stored id — recording that this is a precondition, not proof
- [x] 4.5 **Close the loop by effect**: change one token value, run one generation, grep the produced HTML for the new value. Record the `metadata.json` write-back diff and commit or discard it deliberately
- [ ] 4.6 Verify teardown: `make design-unlink` removes the app-side reference only — the committed package directory untouched, the app's own delete API never invoked — then `make design-link` re-registers cleanly
- [x] 4.7 Record in `design/README.md` what the interface actually exposed — whether the symlink-install route and the picker were reachable through the GUI at all (design.md Open Questions)

## 5. Baseline mockups

> Scope for this change is the workflow being *provably* usable, not a complete gallery. The remaining baselines and any proposals follow as ordinary work once the loop is closed.

- [ ] 5.1 Settle the sidebar-material question before authoring (one screenshot of an installed build), since it decides how mockup panels are painted
- [ ] 5.2 Author the first baseline (`app-shell.baseline.html`) — it establishes the window-chrome markup the other scenarios reuse
- [ ] 5.3 Author a second baseline exercising the widest token slice (`git-review-flat.baseline.html`), including the all-panels-open squeeze at the default window width
- [ ] 5.4 Confirm both baselines cite the source implementing what they draw, and that neither invents a colour outside the token file

## 6. Documentation and completion

- [ ] 6.1 Capture what this change settled into `research/03-analysis/open-design-integration-forensics.md` as a dated addendum — answering the open questions it can, and correcting anything the live run refuted
- [ ] 6.2 Reconcile the trackers: `HISTORY.md` narrative, `research/README.md` index line, and a Learned-refutations entry only if something was genuinely settled beyond re-litigation
- [ ] 6.3 Pre-archive coherence review ⟶ xtty-openspec-critic (add-design-exploration-workflow)
- [ ] 6.4 Archive + reconcile ⟶ archive-ritual
