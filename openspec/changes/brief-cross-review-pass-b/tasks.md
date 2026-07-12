## 1. The command — brief Pass B (and Pass C)

- [ ] 1.1 In `.claude/commands/xtty/cross-review.md`, populate the **brief** on the Pass B invocation: `node "$COMPANION" adversarial-review --base "$B" --model gpt-5.6-sol "<brief>"`, where `<brief>` = one paragraph of design intent + the specific claims/assumptions to soundness-check + a compact digest of any drills the main loop already ran. State that the brief is delivered **inline** and survives verbatim (the companion's single-arg mangler fires only at `argv.length === 1`; `--base` + `--model` keep it > 1 — design D2).
- [ ] 1.2 **Correct the poisoned note** at `cross-review.md:44`: reframe *"Focus text does not scope the review"* to — focus text does **not** change *which* diff is reviewed, but it **is** the brief / soundness-lens channel (`USER_FOCUS`) and **must be populated** every run.
- [ ] 1.3 Give Pass C (the inline Opus soundness pass) the **same brief**, so both soundness passes reason from the same design context (spec: "each soundness pass").
- [ ] 1.4 Document the **gate-inert brief-file fallback** (design D2) — used only when a brief must lead with `-` or exceed `ARG_MAX`; if used, the file MUST be excluded by `cross-review-digest.sh` + allowlisted by `cross-review-scope.sh`.
- [ ] 1.5 Document the **Mode-B rejection** (design D3) as a non-default out-of-band escape hatch — `task --write` loses the schema, adds a write-safety surface (default cwd = the xtty repo root), and OpenAI's content-safety filter aborts security-flavoured drills; revisit only if a real defect proves a briefed read-only pass missed something a drill would have caught.

## 2. Guide

- [ ] 2.1 Update the **worker-protocol** description in `AGENTS.md` (the Pass B bullet under the cross-review section): the worker **briefs** the soundness passes via the focus channel (design intent + claims-to-verify + drill digest), which directs attention without scoping the range or changing the schema; keep the existing "no auto-firing marker" and advisory-only framing.

## 3. Verify

- [ ] 3.1 Verify **by effect** (design D5 — a grep for the brief string in the command file is a read-back check, NOT evidence): run `adversarial-review --base <B> --model gpt-5.6-sol "<a two-question design-soundness brief>"` against a **throwaway** repo with a real diff; confirm (a) the findings **reference the brief's questions** (not generic notes), (b) the output **parses as `review-output`**, (c) the pass stayed **read-only** and the throwaway was the only thing touched.
- [ ] 3.2 Confirm the brief **survives verbatim** inline (newlines intact) on that live call — the first end-to-end confirmation of design D2's source-level claim.
- [ ] 3.3 `openspec validate brief-cross-review-pass-b --strict` (cheap, mechanical — inline).

## 4. Land the change

- [ ] 4.1 Pre-archive coherence review of this change against AGENTS.md's rulebook and live disk state. ⟶ xtty-openspec-critic (brief-cross-review-pass-b)
- [ ] 4.2 **BLOCKING human-attestation cross-review — HUMAN-ONLY, the model MUST STOP.** This change is **mechanically in scope** (it touches `.claude/` and `openspec/specs/`). *Note: the archive gate itself is under a separate unresolved `/opsx:explore` (the `G-GATE` defects) and has no committed executable — that does not exempt this change from the convention.* The **human** (deliberately; never auto-fired) runs `/xtty:cross-review brief-cross-review-pass-b` — **and this is the ideal first dogfood of the A' fix itself**: the very brief this change adds should carry the design intent + claims for its own review. The human reads the complete ledger, runs `scripts/cross-review-digest.sh` themselves, and ticks this task **recording the reviewed-state digest on the delimited attestation line**. The model SHALL NOT tick this task or compute the attested value.
- [ ] 4.3 Archive + reconcile. ⚠️ **COMMIT NOTHING BETWEEN 4.2 AND THIS TASK** — any post-attestation commit touching a reviewed path (incl. `AGENTS.md`) invalidates the digest and, until the re-attestation deadlock is fixed, cannot be re-recorded forward. Attest as the last pre-archive act; archive in the same sitting. Then run step-0's precondition (this change modifies **neither** gate script, so no self-validation hazard), merge the spec delta (`openspec archive`), finish the merge by hand, tick trackers (Current-status row + snapshot + HISTORY narrative + milestone), and verify-against-disk. ⟶ archive-ritual
