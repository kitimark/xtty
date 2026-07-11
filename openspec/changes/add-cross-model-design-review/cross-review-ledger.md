# Cross-review ledger — `add-cross-model-design-review`

> **Advisory in its entirety. Gate-inert.** Nothing in this ledger is read
> mechanically by any downstream step, and nothing here gates archive. Archive
> eligibility lives **entirely** in the human-attestation `⟶ archive-ritual`
> step-0 precondition (AGENTS.md), computed from git — never from anything in
> this file. **"Converged" carries no gate force; a dismissal is a *proposal*,
> not an accepted state; this ledger is not a receipt.** This file is excluded
> by the digest tool and allowlisted by the scope classifier, so its existence
> never affects scope or digest.

## Header — the transparency contract

| Field | Value |
| --- | --- |
| **Reviewed range** | base `B = 0c454cd7cd3c` .. HEAD `bb8b322` (16 files) |
| **Base rule** | positional: parent of the commit that added `proposal.md` (`7cbe0c2`); no ownership metadata. First-commit assertion holds (`proposal.md` + `.openspec.yaml` both landed in `7cbe0c2`, the first change-dir commit) — the change can pass its own gate. |
| **Scope** | **in** (`scripts/cross-review-scope.sh` exit 10 — 6 paths outside the docs/tracker allowlist) |
| **Passes run** | **all three, both rounds** (A ‖ B ‖ C, N=2). None skipped. |
| **Pass A** | Opus — `xtty-openspec-critic` **v4 (2026-07-12)**; delivery-check stamp served==committed both rounds (valid, not stale) |
| **Pass B** | **`gpt-5.6-sol`** (GPT family) at **`xhigh`** effort — model pinned at invocation (`--model gpt-5.6-sol`); effort **config-governed and readable** from `~/.codex/config.toml` (`model_reasoning_effort = "xhigh"`), not per-call-pinned (`adversarial-review` exposes no per-call effort flag — confirms the design's claim). Companion resolved `codex/1.0.6`; `codex.available` + `auth.loggedIn`. |
| **Pass C** | Opus — inline `general-purpose` agent (inherited session model), effort invocation-controlled (session default). NOT a standing agent (anti-roster). |
| **Cross-family?** | **Yes — genuinely two-family soundness** (B = GPT `gpt-5.6-sol`, C = Opus). Not single-model. |
| **Two-model consensus (B∩C)** | **None this run** — the soundness passes diverged (they raised disjoint findings; round 2 B=needs-attention, C=approve/0). One **cross-axis** corroboration (A conformance + C soundness both independently flagged the uncommitted drill harness) — recorded as higher-confidence below. |

## Reviewed file list (verbatim, `git diff --name-only B..HEAD`)

```
.claude/agents/xtty-openspec-critic.md
.claude/commands/xtty/cross-review.md
.claude/commands/xtty/review.md
AGENTS.md
openspec/changes/add-cross-model-design-review/.openspec.yaml
openspec/changes/add-cross-model-design-review/design.md
openspec/changes/add-cross-model-design-review/proposal.md
openspec/changes/add-cross-model-design-review/specs/coherence-review/spec.md
openspec/changes/add-cross-model-design-review/specs/cross-model-review/spec.md
openspec/changes/add-cross-model-design-review/tasks.md
research/03-analysis/cross-model-design-review-axes.md
research/03-analysis/cross-model-review-tar-pit-forensics.md
research/README.md
scripts/cross-review-digest.sh
scripts/cross-review-scope.sh
scripts/test-cross-review-scripts.sh   ← added round 1 (was scratchpad-only)
```

*Honest limitation (surfaced per the protocol): work committed before `proposal.md` **outside** the change dir is invisible to `B..HEAD`. The 16-file list above is the tell for the human — a reviewed scope missing an obviously-touched file would be the sign of an omission. No such omission is apparent.*

---

## Round 1 — the full union ledger (every finding, resolution + rationale)

| # | Src | Sev | Finding | Resolution |
| --- | --- | --- | --- | --- |
| A1 | A (conformance) | REVIEW | Drill harness `test-cross-review-scripts.sh` — the sole evidence for the "12/12 fail-closed drills" cited by tasks 2.8/3.7 + the research doc — was **uncommitted (scratchpad-only)**; unreproducible from a clean clone. | **FIXED** — committed to `scripts/`, repo path relativized to `BASH_SOURCE` (runs from a clean clone); verified **12/12** from the committed location. Also hands `exempt-by-act` its committed regression test (Scenario H). |
| C1 | C (soundness) | MEDIUM | Same uncommitted-harness gap, framed as: the load-bearing `exempt-by-act` check (the unique tripwire for digest-invisible drift) is **prose-only + validated only by an uncommitted file**. | Drill part **FIXED** (= A1; the committed Scenario H now regression-tests exempt-by-act's rewrite+delete arms). "Make exempt-by-act a committed script" part **DISMISSED**: the design deliberately keeps the gate near-zero-machinery + human-run grep (D7/D10); AGENTS.md step-0 already spells the exact `adds==1 && dels==0` grep, and the now-committed harness regression-tests it. |
| A1+C1 | **A∩C (cross-axis)** | — | The harness gap was raised **independently by the conformance and the soundness axis** — higher confidence. | (Fixed as above.) |
| C2 | C (soundness) | MEDIUM | The scope classifier **allowlists the governance docs** (`AGENTS.md`/…), so a change whose *entire* diff is a pure-`AGENTS.md` edit — including one weakening the prose-only gate steps (exempt-by-act, reviewed-base rule, archive step-0, which live **only** as AGENTS.md prose) — is classified **out of scope**. Not among R1–R10. | **DOCUMENTED as residual** (design.md Open Questions, this run). **Not mechanically fixed**: dropping guide docs from the allowlist over-triggers the paid gate on every routine tracker reconcile (the "Keep progress current" edit touches AGENTS.md); the adversarial case reduces to **R3** + human review of governance edits — exactly D10's boundary (thin the claim, don't harden). |
| C3 | C (soundness) | LOW | `digest_stream` emits `DELETED` for an absent path with no presence framing, so a reviewed file whose **entire content is the bytes `DELETED`** aliases its own deletion — technically falsifies D8's "any edit changes the digest." | **SURFACED, not applied.** R3-accepted **and** not-an-accident (nothing accidental produces a 7-byte `DELETED` file), so it sits outside both categories the digest serves (accident tripwire / human-legibility) — hash hygiene, not gate integrity (D10 makes the digest non-airtight anyway). A 2-line `\0DELETED\0` framing is available; deferred. |
| C4 | C (soundness) | LOW | AGENTS.md step-0 says "run the tooling from the reviewed-base version" but gives **no invocation**; the first tooling-*modifying* successor could run the weakened HEAD script. | **SURFACED, not applied.** Latent — bites the *first tooling-modifying successor*, which **does not yet exist** (this change is tooling-introducing). Writing it now is anticipatory machinery ("don't pre-build speculative machinery"). Recovery when it matters: `git show B:scripts/cross-review-digest.sh \| bash -s -- <change>`. |
| B1 | B (soundness) | HIGH | "First end-to-end acceptance test still pending (tasks 5.1–5.3)" — the committed drills exercise only the shell helpers, not the orchestration/attestation/archive. | **DISMISS (informational).** This is a correct statement of the change's own deferred verify tasks — which *this very run* (the live tri-pass = task 2.8 + the worker-half of 5.2) **plus** the human's attestation (5.2) and by-effect archive test (5.3) **are**. Not a design/code defect; it is the acceptance test executing. |
| B2 | B (soundness) | MEDIUM | Once Pass B starts, the worker awaits completion with **no bounded timeout / nonzero-exit / malformed-output / cancellation** handling; the documented skip covers only preflight unavailability. (Empirically also: the companion **rendered a Markdown report** to stdout, while the command says it "emits the review-output JSON schema".) | **Timeout/cancellation machinery REJECTED** (over-engineering for a human-launched, human-present, interruptible main-loop protocol; `run_in_background` surfaces the exit code). **JSON-vs-Markdown doc-accuracy DOCUMENTED** (design.md dogfood note). |

## Round 2 (N=2, the last round) — confirm round-1 fixes clean + surface residual

| # | Src | Sev | Finding | Resolution |
| --- | --- | --- | --- | --- |
| — | A (conformance) | — | **VERDICT COHERENT.** Both round-1 fixes **confirmed clean**: harness committed + 12/12 from its committed location with non-vacuous scenarios matching the cited claims (reproducibility gap closed); design residual note present + consistent with D10. | Round-1 fixes accepted. |
| — | C (soundness) | — | **VERDICT approve, 0 findings.** Independently verified on the real repo: scope in (rc=10, 6 non-allowlisted), digest deterministic across 3 runs, first-commit assertion holds, base-resolution block byte-identical between the two scripts, allowlist fail-closes on edge cases (`packer/Packerfile`, `docs/README.md`, `.github/…` → in-scope). Harness drills non-vacuous + faithful; design note accurate. "No new code-vs-doc contradiction beyond the documented residuals." | Round-1 fixes accepted; converged. |
| rB1 | B (soundness) | HIGH | **Re-record deadlock:** exempt-by-act requires `adds==1 && dels==0` over all history, yet legitimate post-attestation drift forces re-attestation, which must add/modify the sentinel → deadlock without rewriting published history. Codex itself: *"the same re-record deadlock the research identifies as a prior failure mode."* | **ESCALATED / DOCUMENTED as residual.** This is **precisely the documented tar-pit narrowing** (design.md §tar-pit: "pre-attestation rewrite → **re-record deadlock** → …"), independently re-surfaced by the live worker. Codex's recommended fix (a "recoverable attestation epoch") is **the exact non-terminating mechanical hardening D10 refutes**. Intended recovery: attestation is the *last* pre-archive act; legitimate drift is recovered by rewriting the local pre-archive attestation commit (adds stays 1). A graceful mechanical re-attestation path is **deliberately not built**. The happy path (attest → archive with no post-attestation drift) works — verified below. |
| rB2 | B (soundness) | MEDIUM | **Digest quoting:** `git diff --name-only` C-quotes filenames with non-ASCII/tab/newline bytes; the loop treats the quoted string as the literal path → `git cat-file` fails → hashes only the marker, so content changes to that file are invisible to the digest. | **SURFACED, not applied** — same class as C3: needs an implausible accident (a non-ASCII/tab/newline filename in an all-ASCII openspec change) or reduces to R3 (a repo-controlling adversary choosing filenames). A `git diff --name-only -z` NUL-safe transport is a legitimate hardening; deferred (D10 / round-2 bound). |
| rA1 | A (conformance) | REVIEW | **test-precision-vs-claim:** the harness's per-drill claim mapping lives in `tasks.md §3.7` rather than a `design.md` Decision. | **Documented / human-weigh** — D8 already states the load-bearing claim for the by-effect archive test (5.3); a synthetic driver is correct for these narrow script-internal claims. Mild flag, not a coverage hole. |
| rA2 | A (disk-drift) | REVIEW | `AGENTS.md:196` "25 of the **49** archived changes carried a harness delta" is stale → disk yields **25 of 51** (post-archive of this change: 25 of 52). Numerator correct. | **Pre-existing drift, NOT introduced by this change** → the §5.3 reconcile is the fix point. |

---

## Escalated residuals at the N=2 bound (documented, **not fix-fodder**)

Adversarial review never returns zero — a fresh sweep always surfaces further routes. Per the operationalized convergence criterion (*no open actionable beyond documented/accepted residuals* — **not** "both models agree," which has no fixed point) and the tar-pit lesson (**a dev tool is validated by building + using it, not by reviewing its spec forever**), the following are **recorded, not fixed**:

1. **Governance-docs allowlist (C2)** — pure-AGENTS.md gate-gutting is out-of-scope; reduces to R3; a mechanical fix over-triggers the paid gate. *Documented in design.md this run.*
2. **Re-record deadlock (rB1)** — no graceful mechanical re-attestation path after legitimate drift; = the documented tar-pit narrowing; recovery is a local pre-archive commit rewrite; graceful mechanical recovery deliberately unbuilt (D10 — Codex's "recoverable epoch" is the non-terminating trap).
3. **Digest presence/quoting robustness (C3 + rB2)** — the `DELETED` marker aliases a `DELETED`-content file (C3) and C-quoted non-ASCII/tab/newline paths (rB2); both need R3 or an implausible accident; NUL-safe transport + unambiguous framing available, deferred.
4. **Reviewed-base invocation unstated (C4)** — latent until the first tooling-modifying successor exists; anti-speculative-machinery.
5. **Worker runtime robustness (B2)** — no bounded Pass-B timeout/exit/malformed-output handling; low-stakes for a human-present protocol; JSON-vs-Markdown doc-accuracy documented.
6. **AGENTS.md harness-delta count drift (rA2)** — "25 of 49" → 25 of 51/52; pre-existing; a §5.3 reconcile item.
7. **Test-precision flag (rA1)** — harness claim-mapping in tasks.md rather than a design Decision; mild, human-weigh.

**The real proof of the gate is apply-time task 5.3's by-effect fail-closed archive test, not another sweep.** Two of these residuals (rB1, and the C3/rB2 provenance-robustness class) are *themselves* instances of the tar-pit finding this change documents: mechanizing provenance integrity against a repo-controlling model is non-terminating; each closure opens the next narrowing; every member reduces to R3. Their correct disposition is documentation, and stopping.

## Gate state at review end (informational — the worker does NOT compute or record it)

- `tasks.md` tail: 5.2 (human-attestation) and 5.3 (archive) **unticked**; **no attestation line present**.
- Therefore the archive step-0 precondition would **fail closed** today (check 1: no well-formed attestation line). This is the correct **pre-attestation** state. Verified indirectly by Pass C on the real repo.

---

## Authority restatement (non-negotiable)

This entire ledger is **advisory**. **"Converged" has no gate force.** Every dismissal above is a **proposal**, not an accepted state. This file is **not a receipt** and produces **no reviewed-state binding**. Archive eligibility is decided **only** by the human-attestation `⟶ archive-ritual` step-0 precondition (AGENTS.md), computed from git.

**Handoff (task 5.2 — HUMAN-ONLY, the model MUST STOP).** The model has **not** ticked 5.2, **not** computed the digest, and **not** written any attestation line. The **human** now: reads this complete ledger, runs `scripts/cross-review-digest.sh add-cross-model-design-review` **themselves**, and — if satisfied — ticks 5.2 recording the digest on the delimited attestation line. Then task 5.3 exercises the by-effect fail-closed archive proof (a deliberately stale/rewritten attestation must fail closed) before `openspec archive`.
