# Cross-review ledger — add-git-diff-wrap-toggle

Advisory only. Nothing in this file is read mechanically by any downstream step; archive eligibility is the human-attestation gate in `AGENTS.md` (`⟶ archive-ritual` step-0), computed from git, never from this ledger.

## Round 1

**Reviewed range:** base `0ba5056f26a0277d8689942203e8c53e5023bbcc` (parent of the commit that added `openspec/changes/add-git-diff-wrap-toggle/proposal.md`) → HEAD `ecd7431ae4a03e26fff339d8d2da1d182c170dae` at review launch.

**Reviewed file list (this change's own files — the mechanical `B..HEAD` range also swept in ~80 unrelated paths from prior already-archived changes, a known non-attributive artifact of this repo's scope classifier; both soundness passes were briefed to scope to the list below):**
- `App/GitReviewView.swift`, `App/TerminalWindowController.swift`, `App/XttyApp.swift`
- `AppUITests/XttyGitReviewUITests.swift`
- `XttyCore/Sources/XttyCore/GitReviewStore.swift`, `XttyConfigLoader.swift`, `XttyProfile.swift`
- `XttyCore/Tests/XttyCoreTests/GitFileTreeTests.swift`, `XttyConfigTests.swift`
- `openspec/changes/add-git-diff-wrap-toggle/{proposal,design,tasks}.md`, `specs/*`
- `packer/README.md` (the envelope note)

**Passes run:** all three (companion resolved at `1.0.6`, `codex.available: true`, `auth.loggedIn: true` — Pass B ran, not skipped).
- **Pass A** — `xtty-openspec-critic`, Definition v6 (2026-07-18). Verdict: **COHERENT**. No blockers; 2 REVIEW items (AGENTS.md tracker drift), both owed to the not-yet-run archive-ritual.
- **Pass B** — Codex, model `gpt-5.6-sol` (effort: project-config default, not independently confirmed this run). Verdict: **needs-attention**. 4 findings (1 high, 3 medium).
- **Pass C** — inline Fable 5, self-attested served model `claude-fable-5`. Effort inherited from the invoking session (not independently pinned). Verdict: **needs-attention**. 6 findings (0 critical/high, 4 medium, 2 low).

**Brief given to Pass B and Pass C (identical, staged out-of-repo via `mktemp`):** design intent (fixing the ~40%-width-collapse bug + adding wrap/no-wrap modes), 5 specific claims to soundness-check (the PreferenceKey→onGeometryChange diagnosis; the 1pt geometry tolerance; the eager no-wrap VStack's memory cost; the emphasis-across-wrap-point assumption; whether any other test-synchronization race remained after the already-fixed one), a digest of drills already run (Tier-0/Tier-1 results, manual by-effect checks), and an explicit scoping note plus the standing additive instruction to report anything outside the brief.

### Findings and disposition

| # | Pass | Severity | Finding | Disposition |
| --- | --- | --- | --- | --- |
| 1 | B | high | No-wrap's `.frame(minWidth:)` floor applied before padding made every row (even short ones) report ≥ `viewportWidth+16`, so `diffContentOverflows` was tautologically `true` — the automated regression guard could not have caught the bug it exists to catch. | **Fixed** — floor reordered to apply after padding; added a short-line negative-control assertion to the XCUITest. Manually re-verified via the DEBUG state dump (short line → `overflows=false`, long line → `overflows=true`, same session). |
| 2 | B | medium | DEBUG's `viewportWidth` came from an async `onGeometryChange`-fed `@State`, Release's from a synchronous `GeometryReader` — a materially different view tree, and DEBUG's value stayed at its `0` default on a pre-macOS-15 host, silently breaking the no-wrap floor. | **Fixed** — unified on one `GeometryReader`-driven path for both configs; the DEBUG-only geometry signal is now a pure additional observation that never feeds row sizing. |
| 3 | B | medium | No-wrap's eager `VStack` (5000 lines × up to 3000 chars/line, ~15M chars worst case) was unmeasured against the product's lean-memory hard requirement. | **Fixed** (bounded, not benchmarked) — capped no-wrap's eager rendering to 500 rows independent of the parser's cap, with a truncation affordance. A full latency/memory measurement at the cap (Codex's stronger ask) was not run this round — deferred as a possible follow-up if the cap proves too restrictive in practice. |
| 4 | B | medium | The new XCUITest's repo/selection setup depends on OSC 7 shell-integration (zsh-only), so it degrades to the capability-absent arm on bash — contradicting a "shell-independent" claim this session had written into `packer/README.md`. | **Fixed** (documentation only) — corrected the `packer/README.md` note: the test is in the same shell-arm class as its `XttyGitReviewUITests` siblings, not shell-independent. The test itself is unchanged — this is the same correct, already-established pattern every sibling test in the file follows. |
| 5 | C | medium | The single-value `onGeometryChange` overload used is back-deployed to macOS 13 (verified against the installed SDK's `SwiftUICore.swiftinterface`), not macOS 15 — the shipped `#available(macOS 15, *)` gate was factually wrong and its no-op arm unnecessary given the 14.0 deployment target. | **Fixed** — gate removed after independently re-verifying the claim against the SDK interface file myself. |
| 6 | C | medium | (Same underlying issue as B's #2, phrased independently: DEBUG/Release render structurally different trees; only DEBUG was ever verified.) | **Fixed** — covered by the same fix as B's #2. |
| 7 | C | medium | No-wrap's eager-VStack ceiling is unmeasured; suggested a laziness-preserving alternative (pre-measure the widest line, pin a `LazyVStack` to an explicit width). | **Fixed, different mechanism** — took the simpler bounded-cap mitigation (same as B's #3) over the pre-measure+Lazy approach, given round scope; noted as a possible future refinement if the cap proves restrictive. |
| 8 | C | medium | Geometry measurement assumes the `ScrollView`'s outer frame equals the content viewport — would be narrowed by a legacy (space-reserving) vertical scrollbar once a diff is tall enough to show one; not exercised by this change's short-diff tests. | **Accepted residual, not fixed this round** — documented in a code comment at `diffScroll` (design.md R6) for whoever next touches this measurement. |
| 9 | C | low | The store never reset `diffFillsWidth`/`diffContentOverflows` on selection change — a dump could transiently pair a newly selected file with the previous file's stale geometry. | **Fixed** — `GitReviewStore.select`/`apply`'s stale-selection branch now reset both booleans; added 2 unit tests. Manually re-verified via the state dump (selecting file B after file A does not carry A's geometry). |
| 10 | C | low | An emphasis run consisting only of whitespace at a wrap boundary can render invisibly (wrapped trailing whitespace isn't drawn) — cosmetic. | **Accepted, documented** — one line added to design.md R4 naming the edge case; no code change (matches Fable's own recommendation). |

**Escalated residuals (not fixed, carried forward):** R6 above (legacy-scroller viewport assumption); VM tiers (headless/graphics) have not been re-run since round-1's fixes landed — the local Tier-0/Tier-1 re-validation is a separate, mandatory step before attestation, not yet performed as of this ledger entry.

**Round bound:** 1 of 2 (N=2). Whether a round 2 runs depends on what the mandatory post-round-1 Tier-1 re-validation turns up.

---

**Reminder (per protocol): "converged" has no gate force here. Every dismissal above is a proposal, not an accepted state, until the human reads this ledger. There is no receipt. The archive gate is the human attestation in `tasks.md`, computed independently from git by `scripts/cross-review-digest.sh`.**
