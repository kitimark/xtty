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

Every ceiling number proposed by reasoning (33.4 KB, 46 KB, 50 KB) was an **undrafted estimate** and all were refuted. The first notch is the **achieved** size: the diet landed at **64,079 B**, so the initial ceiling is **65,666 B** *(the tier-fix-only floor, giving ~1.6 KB of headroom)*. A ratchet **cannot ship broken**, because it is set from a state that already exists.

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
- **[A ceiling with only ~1.6 KB of headroom will bite soon]** → That is the *point* of a ratchet; the refusal protocol (park the finding) is the designed response, not an emergency.
- **[Claude Code's eager-loading semantics are an external spec that will change]** → The meter is a **compatibility surface**. Each rule is pinned by a fixture citing the doc sentence it implements, so a docs change surfaces as a failing fixture rather than a silent hole.

## Migration Plan

1. Land the gate **with the ceiling already satisfied** (the diet is committed: 64,079 B < 65,666 B) ⇒ the gate is **green on arrival** and no work is frozen.
2. Arm existing clones via the order-only `hooks` prerequisite on the routine `make` entry points.
3. **Rollback:** `git config --unset xtty.guide-gate` disarms the hook in one command, with no history rewrite.

## Open Questions

- **Should the ceiling ratchet below 65,666 B now?** The next notch (~57–58 KB) needs an ablation of the `rules`/status surface that has not been drafted. Deferred — a ratchet notch must be **measured, never estimated** (D6).
- **Should the `Stop`-hook / `PreToolUse` advisory layers ship at all?** They are strictly weaker than the gate and add surface. Currently **out of scope**.
