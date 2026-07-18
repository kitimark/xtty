## Context

`AGENTS.md` regrew to ~80 KB twice after being dieted, both times through **instructed** writing. The leanness rule already exists at spec grade, at the point of action, and at review time (proposal §Why) — so the gap is **admission to the eager tier**, not reach.

This design is unusual in one respect worth stating up front: **it was not derived by reasoning — it was derived by 14 rounds of adversarial cross-model review followed by building the thing and running it.** Three candidate engines and a dozen candidate rules were killed **by measurement**. The prototype (`research/artifacts/guide-gate/`) is **45/45 green with an 18-mutant matrix proving every fix load-bearing**. Everything below cites the measurement that settled it, because most of the plausible-sounding alternatives are already refuted.

## Goals / Non-Goals

**Goals:**
- A gate that **cannot be routed around by an honest session** — no matter which tool writes the file or which wrapper pushes it.
- **Never freeze the repo.** A shrinking or unchanged push always passes; unrelated work is never refused.
- **Never lose a finding.** A refused append is *parked*, not dropped.
- The gate **measures what is actually injected**, and is honest about what it does not measure.

**Non-Goals:**
- **Adversarial resistance.** A repo-controlling model can `--no-verify` or rewrite history. That is the accepted **R3** residual, the same trust class the repo already accepts for every committed procedure. This gate is an **accident tripwire**, and saying so is part of the design.
- Bounding **lazy** surfaces (`research/`, `HISTORY.md`, skills). They are the *destination* of the park protocol, and the design's whole premise is that content should move there.
- Enforcing `CLAUDE.md`↔`AGENTS.md` **parity** (that is `agent-guide-parity`'s job). The meter is deliberately parity-agnostic: it measures the resolved injection whatever shape it takes.

## Decisions

### D1. The engine is a git `pre-push` hook — the other three candidates are REFUTED by measurement

| ❌ engine | why it died |
|---|---|
| a blocking **CI check** | `git log --merges \| wc -l` → **0 merge commits, ever.** `main` is unprotected and every commit is a direct push ⇒ **CI runs *after* the push.** Post-hoc advisory = the 4th advisory surface after three that already lost. |
| **`PreToolUse` on `Edit`/`Write`** | hooks match **tool calls, not filesystem writes** — and **the bloat arrived through Bash** (`dca6b114`, a `python3` heredoc, grew the file 59,404 → 61,684 B). An honest session bypasses it by reaching for Bash. |
| **`PreToolUse` on `Bash`** matching `git push` | the matcher filters the **tool name**; `Bash(git push *)` is a best-effort *permission* filter, not a regex over the command. `git -C "$PWD" push`, `git -c k=v push`, `make publish`, a wrapper, `gh` — **all miss.** |

A `pre-push` hook sits **below the agent**: it does not care what wrote the file or what invoked the push.

### D2. Install into the repository's **own git dir** — a hook in the worktree is disarmed by `git checkout`

`core.hooksPath=.githooks` resolves **relative to the top of the working tree**, and git **silently skips a hook file that is not on disk**. Measured end-to-end: `git checkout <a branch that predates the hook> && git push origin main` published **`main`** with **no gate output at all** — and this repo has **three such pre-hook branches today**.

⇒ the tracked `.githooks/pre-push` is the **reviewable source**; `make hooks` installs a **copy into `$(git rev-parse --git-common-dir)/hooks`**, which `checkout` cannot reach. Measured green from `main`, from a hookless branch, from a **detached HEAD**, and from a **linked worktree**.

⚠️ **Do NOT install into `$(git rev-parse --git-path hooks)`** — it **follows a foreign `core.hooksPath`, including a *global* one**, and the installer then writes xtty's gate into the user's **global hooks dir**, where it **fires on every other repository they push**. Measured: an unrelated project's push blocked by xtty's gate. ⇒ if `core.hooksPath` is set at all, **warn and STOP; never write into a hooks dir we do not own.**

### D3. Identity is a **repo stamp**, and it is checked FIRST

`make hooks` writes `git config xtty.guide-gate true`; the hook acts only on a repo bearing that stamp. *"Any repository that has an agent guide"* is **not** an identity — a shared hook would gate a stranger's project with this project's ceiling.

⚠️ **The stamp check must precede the ceiling parse.** With the order reversed, a typo'd `XTTY_GUIDE_CEILING` in a shell profile made the malformed-ceiling refusal fire in an **unstamped stranger's repo**. ⚠️ And it must **not** be keyed on `HEAD` — that made the guard **self-disabling** (deleting the guide disabled the guard whose job is to refuse the deletion).

### D4. The meter: the **eager-root set**, resolved, weighed in **bytes by git**

Measure the **committed blob of the pushed tree**, never the disk (`git push` transmits objects; `wc` measures the worktree — this breaks in both directions).

The eager roots, per the Claude Code docs: **`CLAUDE.md`**, **`.claude/CLAUDE.md`**, **`CLAUDE.local.md`** (*"loads alongside CLAUDE.md and is treated the same way"*), and **unscoped `.claude/rules/**`** (*"rules without `paths` frontmatter are loaded at launch"*). Follow `@`-imports **transitively (max depth four hops)**, **anywhere in a line**, **skipping code spans and fenced blocks**, resolving **relative to the containing file**.

Four traps, each of which shipped and was caught only by **running** the code:
- **A symlink blob contains its target path.** `git show <oid>:CLAUDE.md` on `main`'s `120000` link returns the 9-byte string `"AGENTS.md"` — **not the 81 KB guide**. Read the tree **mode**; follow the link. *(The meter read **9 bytes** for the entire file.)*
- **`${#body}` counts characters, not bytes** — and this guide is full of `❗✅⚠️`. Ask git: **`git cat-file -s`**.
- **A rule's frontmatter is YAML delimited by `---`.** A `grep '^paths:'` both misses the delimiters and **falsely exempts a rule whose body starts a line with `paths:`** — an unmetered fake-diet lane inside the metering code.
- **A `.claude`-only guide (no root `CLAUDE.md`) must still be metered.** "No guide" means the eager-root **set is empty**, not that the root is absent.

### D5. The comparator: **growth-vs-baseline**, with a fork-point first-push rung

*"Permit only strictly-decreasing edits while over budget"* is **uncomputable from a snapshot** and **freezes the repo** (during the red window an *untouched* file is not "strictly decreasing" ⇒ every unrelated push refused).

- **while OVER the ceiling:** refuse iff `current > baseline` ⇒ a shrink or an unchanged push always passes.
- **once UNDER:** refuse iff `current > ceiling`.
- **Baseline ladder (order matters):** an already-published-identical closure ⇒ allow · `$remote_oid` (if it resolves locally) · the local tracking ref · **first push ⇒ the FORK POINT (`git merge-base`)** · else, guide-bearing ⇒ the absolute ceiling; guide-less ⇒ allow.

The fork-point rung exists because *"a new ref inherits remote `main`'s guide"* **inverts once the diet lands**: a ref anchored in pre-diet history (a bisect branch, a hotfix off `v0.0.1`) is then refused for growth **it did not cause**, of objects **already on the remote**. Measured: the guide exceeds the initial ceiling on **3 of 17** days of this repo's history, 57 KB on **8**, 50 KB on **10**; **`v0.0.1` = 52,626 B and is an ancestor of `main`.**

### D6. The ceiling is a **measured ratchet**, and it may only decrease

Every ceiling number proposed by reasoning (33.4 KB, 46 KB, 50 KB) was an **undrafted estimate** and all were refuted — and even a *measured* snapshot goes stale: the diet landed at 64,079 B (`e50cc2b`, 2026-07-13), then a further diet landed at **51,252 B** (2026-07-17, via `/doctor`'s derivability pass) before this change was even applied, which would have silently permitted ~14 KB of undetected regrowth had a ceiling stayed hardcoded at the first number. ⇒ **the ceiling is a single numeric literal** — line 32 of `.githooks/pre-push`, `CEILING="${XTTY_GUIDE_CEILING:-N}"`, the prototype's own env-override-with-default idiom, unchanged by this change's own "port it, do not redesign it" rule — **edited in two steps, not one, and the gate is not armed until the second step is done.** Task 1.3 edits `N` to an early, *provisional* value (so tasks 2–4 have something to reference) by measuring `AGENTS.md`'s committed size at that moment. This change's own documentation tasks (5.1–5.3) then grow `AGENTS.md` further, so task 5.4 **commits 5.1–5.3, re-measures the now-committed state, and edits `N` again to finalize it**, plus the same ~1.6 KB headroom. Spec `agent-guide-budget`'s "may only ever be lowered" rule is a **review-time discipline governing future edits to this line** — nothing in the file itself distinguishes a "provisional" from a "finalized" value; there is no separate ratchet marker or comment, only the one literal — so the rule applies from the finalized value onward, once the gate actually ships armed with it, not to the provisional-to-finalized edit itself. **Only then does task 5.5 wire `hooks` into the build (arm the gate)** — deliberately sequenced after 5.4, not in section 2 where an earlier draft of this design placed it, because arming before finalizing would install a ratchet at the provisional value and then require 5.4 to raise it, an armed-ratchet violation. `make hooks` never recomputes anything at runtime; like every other line of the tracked hook, the finalized literal is copied verbatim to every clone (D2); only a **later, explicit** edit to the tracked source can lower the ratchet further. **One residual write remains after 5.5's arming:** task 7.3's archive-reconcile (⟶ archive-ritual) also edits `AGENTS.md` — a bounded status-row update per AGENTS.md's own "Keep progress current" rule. Once armed, this write is subject to the gate exactly like any other push: if it doesn't fit inside the ~1.6 KB headroom, the correct response is the **park-don't-lose protocol** (5.2, route the overflow to `HISTORY.md`), never re-opening 5.4 to raise the already-armed ceiling — see Risks and the Migration Plan.

### D7. **Fail CLOSED — but with guards that actually refuse, not a trap that lies**

Measured: under `set -u`, macOS **bash 3.2** errors on `"${arr[@]}"` for an **empty array**; the meter died mid-measurement and the hook **still exited 0** — installed, armed, sentinel-stamped, and **completely inert**. And the `set -E` + `ERR` trap written to fix that **printed *"INTERNAL ERROR … refusing rather than failing open"* and then ALLOWED the push** (it fired on an *expected* `return 1` inside a command substitution, whose `exit 1` killed only the subshell) — **six such lines in a fully-green run**.

⇒ **no ERR trap.** Fail-closed is carried by **explicit `is_int` guards** on every lane, which actually refuse. **A gate that fails open on its own bug is not a gate; a gate that cries wolf discredits the only channel it has.**

### D8. Test precision vs. the claim

**The claim:** *"a push that grows the eagerly-injected guide past the ceiling is refused, and one that does not is allowed."*
**The layer it lives in:** the **git transport boundary** — after the objects are committed, before they reach the remote. It is decided by the hook's exit status, and it depends on git's own behaviour (hook lookup, symlink blobs, `$remote_oid` advertisement, stdin ref lines).
**Why the driver reaches it:** the fixtures are **real `git push` invocations against real bare remotes**, in **isolated scratch repositories** (fresh repo + remote per arm). Nothing shallower can reach this claim: **four of the design's worst defects were invisible to 14 rounds of review and to any unit test of the meter** — they lived in git's semantics (the symlink blob), bash's (the empty array), the hook's install location, and the interaction between two correct rules. They appeared on the **first execution** of a real push.

⚠️ **A fixture that never fails is decoration.** Every fix is therefore paired with a **mutant** that reverts it; the arm guarding it **must go red**. This is not ceremony — **four of this suite's own arms were green and proving nothing** until the matrix exposed them (including one whose label claimed a lane it never exercised).

⚠️ **Setup failure must be FATAL.** An earlier suite reported **21 "passes"** in a sandbox where `mktemp` was failing. **A green suite that never ran is a lie.**

## Risks / Trade-offs

- **[A docs-only clone never runs `make` ⇒ never armed]** → Accepted in writing; routed to the CI detector lane. Nothing can force it.
- **[The meter is a proxy — the objective is TOKENS, and bytes are not monotonic in tokens]** → Stated in the spec. The gate bounds a *proxy*; the ratchet is validated by a startup-token measurement (`claude -p`, baseline **57,569**).
- **[Block-level HTML comments are stripped before injection, so the meter over-counts]** → Conservative direction (it can only over-refuse, never under-refuse). Documented.
- **[The gate can be bypassed with `--no-verify`]** → **R3, accepted.** This is an accident tripwire, not an adversarial guarantee. **Do not harden it against the model that runs it** — that is a documented tar-pit (G-TARPIT-1).
- **[A ceiling with only ~1.6 KB of headroom will bite soon]** → That is the *point* of a ratchet; the refusal protocol (park the finding) is the designed response, not an emergency. The **first** consumer of that headroom is this change's own task 7.3 archive-reconcile — if its bounded status-row update doesn't fit, apply the **park-don't-lose protocol** (5.2) to the overflow (route it to `HISTORY.md`, exactly where archive-reconcile's full narrative already goes by convention, and keep only the mandatory bounded pointer in `AGENTS.md`). **Never re-open task 5.4 to raise the ceiling once 5.5 has armed the gate** — that is precisely the armed-ratchet violation this design exists to prevent; a breach at this point is a signal to park content, not a license to widen the gate.
- **[Claude Code's eager-loading semantics are an external spec that will change]** → The meter is a **compatibility surface**. Each rule is pinned by a fixture citing the doc sentence it implements, so a docs change surfaces as a failing fixture rather than a silent hole.
- **[Two ladder lanes still trust a possibly-stale local tracking ref for `$REMOTE/main`, narrower siblings of the class A-15-1 fixed]** → Found by `/xtty:cross-review`'s inline soundness pass (2026-07-18, confidence 0.45 — both require an unusual, non-routine precondition, not an honest push). (a) The **first-push fork-point rung** (`git merge-base "$local_oid" "$MAIN_REF"`) uses the pusher's own local tracking ref for `main`; if `main` were later **rewritten** (not just advanced) to strip old bloat, a clone that never re-fetched still computes a fork-point in the pre-rewrite (fatter) history. (b) **Rung 0**'s `canonical`/`canon_digest` are resolved once, at hook start, from that same local tracking ref; A-15-1b already closed the "same content, different commit" hole, but the remaining "real same-commit repoint, 0 new objects" fast path still assumes the remote hasn't since GC'd objects only that stale local ref still names. **Accepted, not fixed**: both need history-rewrite-plus-stale-fetch or remote-GC-of-still-locally-referenced-objects — materially rarer than A-15-1's routine "diet via new commit, unfetched clone" case — and hardening every tracking-ref read in the ladder against every staleness variant is an unbounded pursuit (G-TARPIT-1: don't harden a mechanical gate against every conceivable adversarial replay). `git fetch` before a first push or a rung-0-eligible push closes both in practice.
- **[A literal embedded NEWLINE in a dangling import path is not closed by A-C-1's field-order fix]** → Round-2 soundness pass (2026-07-18, confidence 0.85). A-C-1 moved `dangling` to the LAST field specifically to survive an embedded SPACE (the realistic case — arm 40 shows honest rule filenames use spaces); it does not survive a raw newline byte, since the outer `resolve_guide` return is itself a single `printf`/`read` LINE. **Accepted as an R3 adversarial-construction residual, not fixed** — an honest session does not create newline-embedded filenames, unlike the space case. Documented directly at the A-C-1 comment site in `.githooks/pre-push` so the claim there doesn't overstate its own coverage.
- **[Checking out an OLD commit and running a routine `make` target from it can downgrade the SHARED common-dir hook for every worktree]** → Codex-found (2026-07-18, round 2). `install-hooks.sh` writes into `$(git rev-parse --git-common-dir)/hooks`, shared by every linked worktree (D2's own design); an old checkout's old installer has no knowledge of any safety mechanism added after that commit (e.g. A-C-5's hash-tracking didn't exist before this session). **Accepted, not fixed** — this is a property of D2's whole architecture (any git-tracked artifact that writes to a shared, non-per-checkout location has it), not a regression this session introduced, and it requires the deliberate/unusual act of running build tooling from a checked-out historical commit rather than the current branch tip. A monotonic-sentinel or ownership-epoch scheme would close it but is a materially bigger design change than this change's scope; revisit only if this is ever observed in practice, not speculatively.
- **[Deleting a non-root eager root (`.claude/CLAUDE.md`, `CLAUDE.local.md`, or an unscoped rule) while `CLAUDE.md` survives is not flagged as a "deletion" the way A-1's root-deletion rule flags the root]** → Codex-raised (2026-07-18, round 2), **considered and NOT treated as a defect**: this is the comparator's intended behavior, not a gap. `root_gone`/A-1's special deletion handling exists specifically because losing `CLAUDE.md` — Claude Code's canonical entry point — can silently disable the *entire* eager-injection mechanism the gate exists to bound (the "self-disabling gate" failure this design's identity guard already worries about elsewhere). Losing a *secondary* root has no such self-disabling property: `CLAUDE.md` still resolves, Claude Code still loads *something*, and the byte total genuinely shrank — exactly the "always permit a shrink" comparator D5 already commits to. Treating every eager root's deletion identically to the canonical root's would misclassify a legitimate diet action (removing content specifically to reduce the eagerly-injected total) as a refusal-worthy event.

## Migration Plan

1. Land the gate **green on arrival, by headroom rather than unconditional construction** — task 5.4 finalizes the ceiling against `AGENTS.md`'s actual *committed* state after this change's own documentation edits (5.1–5.3) have landed (D6). The one write remaining after 5.5 arms the gate is task 7.3's bounded archive-reconcile status-row update, which the ~1.6 KB headroom is sized to absorb; if it doesn't fit, park the overflow (5.2's protocol) rather than raise the now-armed ceiling — see Risks.
2. **Arm** (task 5.5, deliberately *after* 5.4, not in section 2) — wire `hooks` as the order-only prerequisite on the routine `make` entry points, so no clone is ever armed with the provisional ceiling.
3. **Rollback:** `git config --unset xtty.guide-gate` disarms the hook in one command, with no history rewrite.

## Open Questions

- **Should the ceiling ratchet below the achieved-at-finalization size?** No — D6 already ties the finalized ceiling (task 5.4, after this change's own documentation edits land) to whatever `AGENTS.md` has achieved by then, so this resolves itself. What's still open: the 2026-07-17 diet reached 51,252 B via a *derivability* argument (cutting content an agent could reconstruct from the codebase, e.g. the directory tree and the redundant-with-`make`'s-own-`--help`-equivalent command table), not via the formal **ablation** methodology D6 references for cutting decision-time rules — a genuine sub-50 KB reduction still needs that ablation (extending the 2026-07-06 methodology) and remains deferred.
- **Should the `Stop`-hook / `PreToolUse` advisory layers ship at all?** They are strictly weaker than the gate and add surface. Currently **out of scope**.
