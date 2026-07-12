---
name: "XTTY: Cross-review"
description: "Authority-free cross-model design review of an in-scope OpenSpec change — conformance (Opus critic) ‖ two-family soundness (Codex/GPT + inline Opus) merged into one advisory union ledger with a heuristic consensus flag, bounded fix→re-review rounds, and detectable non-gating degradation. Carries ZERO gate force; the human gate lives in the archive ritual."
category: Workflow
tags: [xtty, openspec, cross-model, review, codex, adversarial, gate]
---

This is a **main-loop protocol**, not a subagent delegation. You (the invoking session) run it directly — a subagent cannot own a detached background reviewer without stranding it (the `run_in_background` strand refutation). The individual passes are observe-only; **you** adjudicate and apply fixes between rounds.

**Authority boundary (non-negotiable).** Everything this worker produces — the ledger, its consensus flags, its coverage description, every recorded dismissal — is **advisory in its entirety**. Nothing it writes is read mechanically by any downstream step, and nothing it writes gates archive. Archive eligibility lives **entirely** in the human-attestation gate (the `⟶ archive-ritual` step-0 precondition in AGENTS.md), computed from git, never from anything this worker wrote. "Converged" carries **no** gate force; a dismissal is a **proposal**, not an accepted state; there is **no receipt**.

**User-launched only; one launch authorizes the whole bounded run.** This command is human-invoked — no `tasks.md` marker auto-fires it, and the model driving an apply loop MUST NOT invoke it on its own. A single human launch authorizes the entire bounded run (up to N rounds of the paid external Pass B). Spend is human-initiated **per run**.

`$ARGUMENTS` is the change name (e.g. `add-cross-model-design-review`). If empty, ask which change.

---

## 0 — Scope + range (deterministic, no ownership metadata)

1. **Applicability is the human's call to launch** — but confirm the change is *worth* a cross-model run by the mechanical classifier: `scripts/cross-review-scope.sh <change>` (exit 10 = in scope; exit 0 = docs/tracker-only, the single-agent `/xtty:review` suffices; exit 2 = refuse). This mirrors the archive gate's classifier so the human sees the same verdict.
2. **Resolve the review base B deterministically** — B = the **parent of the commit that added the change's `proposal.md`** (a purely positional git rule; **no** ownership trailers/manifest). Both committed scripts already encode this with the fail-closed range-omission assertion; reuse it: `git rev-parse "$(git log --diff-filter=A --format=%H -- openspec/changes/<change>/proposal.md | tail -1)^"`. If `scripts/cross-review-scope.sh` refused (exit 2 — a commit predates `proposal.md`), **stop and report** rather than silently narrowing the range.
3. **Require a clean tree** before firing (`git status --porcelain` empty). **Checkpoint-commit** any fixes you apply each round so `B..HEAD` always reflects the reviewed state.
4. **Honest limitation to surface in the header:** work committed *before* `proposal.md` **outside** the change dir (e.g. product code landed pre-proposal) is invisible to `B..HEAD`. This is best-effort isolation, not proof every range commit belongs to the change — the human catches an omission via the header's **named file list** (a reviewed scope missing an obviously-touched file is the tell).

## 1 — Locate the external reviewer (portable, version-ordered) + availability

- **Resolve the companion version-independently**, highest version **numerically** (not lexically):
  ```
  COMPANION="$(ls -d "$HOME/.claude/plugins/cache/openai-codex/codex/"*/scripts/codex-companion.mjs 2>/dev/null | sort -V | tail -1)"
  ```
  `${CLAUDE_PLUGIN_ROOT}` is unset in a project command, so the glob is the only portable resolution. (`sort -V` is load-bearing: lexically `1.0.9 > 1.0.10`, numerically `1.0.10 > 1.0.9`.)
- **Read availability, to decide run-or-skip only** (never to gate): `node "$COMPANION" setup --json` → `node.available`, `codex.available`, `auth.loggedIn` (note `status` has **no** `ready` field; `setup` normalizes a connect-failure and a genuine logout into the same `loggedIn:false`). Run Pass B **iff** the companion resolved **and** `codex.available` **and** `auth.loggedIn`; otherwise **skip Pass B, complete on the remaining passes, and say so in the header** (which passes ran, which did not, and why). A present-but-broken integration MAY be a header warning. **No** availability state auto-satisfies or auto-blocks archive.

## 2 — Run the three passes (A ‖ B ‖ C, then barrier-merge)

Launch all three concurrently; **await Pass B's completion before merging** (the main loop owns the call, so this is safe):

- **Pass A — conformance (Opus critic).** Spawn the `xtty-openspec-critic` agent by name on `<change>`. **Delivery check:** its report's first line must read the current stamp (`Definition: v4 (2026-07-12)` or later — compare against `.claude/agents/xtty-openspec-critic.md`). A stale stamp means the harness served a cached older definition (edits propagate with unpredictable lag) — treat that as a **blocker for the run**, not a valid Pass A. *(This is why a self-dogfood of a change that edits the critic must run in a **fresh session** after v4 is committed — R9.)*

- **Pass B — external soundness (Codex / GPT family).** Run the companion **backgrounded via the harness's Bash `run_in_background: true`** — the companion's own `--background` is a **no-op for `adversarial-review`** (always foreground), so the harness must do the backgrounding; **never** own it from a subagent (strand refutation). **Pass B carries a BRIEF as the trailing positional** (this is the load-bearing input — a bare diff makes Pass B review in the dark; measured, it then endorses plausible-wrong claims it has no context to test):
  ```
  node "$COMPANION" adversarial-review --base "$B" --model gpt-5.6-sol "$BRIEF"
  ```
  Build `$BRIEF` (one inline paragraph, delivered **verbatim in meaning** — the companion reconstructs focus as `positionals.join(' ').trim()`, so internal newlines survive but it is not byte-identical; `--base` + `--model` keep `argv.length > 1` so the single-arg mangler never fires) from three parts: **(1) design intent** — what the change is trying to do; **(2) the specific claims / assumptions the soundness pass must verify** — the author's actual uncertainties, framed as *"soundness-check these"*, never *"confirm X"*; **(3) a compact digest of any drills the main loop already ran**, presented **as claims to challenge**, not established fact. **The brief is ADDITIVE:** end it with an explicit instruction to *"soundness-check these claims **and** report any material finding outside this brief"* — a brief that omits a risk must not blind the reviewer to it (measured: without this, a brief crowds out open-ended findings). If a brief would exceed the inline budget, **compact it and note the compaction** — never silently under-brief, and never spill it to a separate file (the digest tool excludes only the ledger, so any other new file enters the attested reviewed state). The brief is **advisory** — it never gates archive.
  - Pin the **model** explicitly with `--model gpt-5.6-sol` (the GPT-family model the local codex CLI is configured with). `--model` **is** honored on `adversarial-review` even though its usage banner omits it (the review-command arg parser accepts `base/scope/model/cwd`). There is **no per-call effort flag** — the expected **`xhigh`** effort is governed by the codex CLI's own config, an *expectation*, not an invocation pin. The brief (focus text) does **not** change *which* diff is reviewed — the input is the full `B..HEAD` diff — but it **is** the brief / soundness-lens channel (`USER_FOCUS`) and **must be populated** every run. Emits the `review-output` JSON schema.
  - **Do NOT reach for `task --write` to give Codex a drilling capability** (rejected — `research/03-analysis/codex-review-integration-forensics.md`): it loses the server-enforced schema, adds a write-safety surface (its default cwd is the **repo root** — any `--write` use REQUIRES an explicit throwaway `--cwd`), and OpenAI's content-safety filter aborts security-flavoured drills mid-run. Run drills in the **main loop** and hand Codex the *results* in the brief. Revisit only if a real defect proves a briefed read-only pass missed something a drill would have caught.

- **Pass C — inline soundness (Opus), the diversity slice.** An **inline** `Agent` call (NOT a new standing committed agent — the anti-speculative-roster refutation), prompted to do an adversarial **design-soundness** review mirroring Pass B's lens (challenge the approach, assumptions, tradeoffs, failure-under-real-conditions), **given the same `$BRIEF`** (design intent + claims-to-verify + drill digest, with the same additive *"…and report anything outside this brief"* instruction), and **forced to emit Codex's real `review-output` schema** so B and C are directly comparable. When both soundness passes share the brief, do **not** flag a finding as two-model consensus if both rest **only** on the same briefed assertion — shared framing is not independent corroboration; record the brief in the ledger so the human can audit it.
  ```json
  {"verdict":"approve|needs-attention","summary":"…","next_steps":["…"],
   "findings":[{"severity":"critical|high|medium|low","title":"…","body":"…",
     "file":"…","line_start":1,"line_end":1,"confidence":0.0,"recommendation":"…"}]}
  ```
  (Per-finding keys exactly: `severity,title,body,file,line_start,line_end,confidence,recommendation` — **no `line`**, `additionalProperties:false`.)

## 3 — Merge into one advisory union ledger

Merge A + B + C into a **single source-tagged union ledger**. Each finding is tagged by its originating pass. Flag a finding raised by **both soundness passes (B and C)** as a **heuristic two-model consensus** signal of higher confidence — a *semantic* same-finding judgment across differently-modeled reviewers (they diverge on title, file attribution, line ranges), **not** a mechanical join.

**Ledger header (the transparency contract) names, verbatim:**
- the reviewed **range**: base `B`, `HEAD`, and the **reviewed file list** (`git diff --name-only "$B"..HEAD`);
- **which passes ran, which did not, and why** (a skipped Pass B → the header says **single-model**);
- the **effective model of each soundness pass** — and its **effort where determinable** (Pass C's effort is invocation-controlled; Pass B's is reported from the codex config when readable, else marked **undetermined**). A divergent/unreadable local config yields an honestly-labeled header, never a blocked gate;
- the **brief** the soundness passes were given (the design intent + claims-to-verify + drill digest, or a faithful reference) — so the human can audit the shared framing behind any consensus flag; and the **resolved companion version** (Pass B's arg-survival is verified against a specific version — record it so a later version bump is a visible re-probe trigger, not a silent regression).

The ledger MAY be persisted as an **advisory, gate-inert** `openspec/changes/<change>/cross-review-ledger.md` (excluded by the digest tool + allowlisted by the scope classifier, so persisting it never affects scope or digest). **Nothing downstream reads it mechanically.**

## 4 — Bounded fix→re-review loop (worker behavior, not eligibility)

- Each round: run A ‖ B ‖ C, then **adjudicate every finding** as **fix** or **dismiss-with-recorded-rationale**; apply fixes (checkpoint-committed); re-review.
- **Bound N = 2 rounds.** On the bound, **escalate the residual** (state it plainly) rather than looping further.
- Surface the **complete** union ledger — **every** finding with its resolution, **every** dismissal with its recorded rationale, and any escalated residual — to the human on **every** run, never a filtered subset. The human gate rests **entirely** on reading this, so completeness is load-bearing, not a courtesy.
- Restate at the end: **"converged" has no gate force, a dismissal is a proposal (not an accepted state), and the worker produces no receipt or reviewed-state binding.** If this is the change's own dogfood, the **human** (not you) then reads the ledger, runs `scripts/cross-review-digest.sh <change>`, and records the digest on the delimited attestation line — see the `⟶ archive-ritual` step-0 precondition in AGENTS.md.

---

**AGENTS.md is the source of truth** for the worker protocol, the mechanical path-based scope classifier, and the human-attestation gate — this command operationalizes them; if anything here conflicts with AGENTS.md, AGENTS.md wins.
