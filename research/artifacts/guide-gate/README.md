# guide-gate — the working prototype behind `bound-the-agents-md-guide`

**Provenance:** 2026-07-13/14, round 12 of the cross-model review loop. These are the *measured*
artifacts, not a sketch: the suite is **19/19 green** and the mutation matrix proves every fix
load-bearing. They exist because **11 rounds of two frontier models reading English missed four
defects that the first execution of the code found in seconds** (see
`../03-analysis/agents-md-structural-best-practices.md` §A5-tricies-quinquies, and G-TARPIT-7).

| file | what it is |
| --- | --- |
| `pre-push` | the gate. Meter = resolve `CLAUDE.md` in the **pushed tree** + follow `@`-imports transitively; refuse growth past the ceiling. **Fails CLOSED.** |
| `install-hooks.sh` | `make hooks`. Installs into the repo's **own git dir** (checkout cannot reach it). Refuses to write into a hooks dir it does not own. |
| `suite.sh` | 19 **isolated** fixtures (fresh repo + remote per arm — they were coupled, and one red cascaded into fake reds). |
| `mutants.sh` | reverts each fix; the arm guarding it must go red. **A fixture that never fails is decoration.** |

    bash suite.sh      # 19/19
    bash mutants.sh    # every mutant dies at the right arm

## The four defects only execution found

1. **The meter read 9 bytes for the whole 81 KB guide.** `git show <oid>:CLAUDE.md` on a **symlink**
   (`120000` — **main's actual shape**) returns the link *target* (`"AGENTS.md"`), not the content.
   The gate could never see growth. Read the tree **mode**; follow the link.
2. **The gate failed OPEN on its own crash.** Under `set -u`, macOS **bash 3.2** errors on
   `"${arr[@]}"` for an **empty array**. The meter died mid-measurement and the hook **still exited 0**
   — installed, armed, sentinel-stamped, and **completely inert**, its own error buried in git's
   transfer output. ⇒ ERR-trap + an integer guard: **any internal error REFUSES.**
3. **The repo-identity guard was self-disabling** — keyed on `HEAD`, so *deleting the guide disabled
   the guard whose job is to refuse guide deletions.* Key it on the **published baseline** too.
4. **A fixture was vacuous** — arm 14 was green and proved nothing (built post-diet it was a *shrink*
   through the ordinary comparator). Only the **mutation matrix** could see that.

## Round 12 — the models reviewed the CODE, and found 11 more (all fixed, all fixtured)

Once the artifact stopped being prose, the findings stopped being arguments. Every one came with a
command. **29/29 green.**

**gpt-5.6-sol (6):** the meter counted **characters, not bytes** (`${#body}` — and this guide is full
of `❗✅⚠️`; a Unicode-only edit grew the blob with **no growth seen**) ⇒ ask git: `git cat-file -s` ·
the declared **4 import hops only followed 3** (the root consumed one) · dangling-import status was
**aggregate, not per-path** (a *newly* broken import was mis-read as a deletion) · the identity guard
matched *"any repo with a guide"*, **not xtty** · an **empty** `core.hooksPath` slipped the installer's
"is it set" check while git searched the worktree root · the hook **hardcoded `origin`**, ignoring the
remote name git passes as `$1`.

**fable-5 (5) — three of them against its own earlier fixes:**
- **D-1 — the symlink fix only handled path DELETION, not a MODE FLIP.** Replace the `120000` link with
  a **9-byte regular file** containing the literal text `AGENTS.md` (a zip round-trip, `rsync` without
  `-l`) and the injected guide really *is* 9 bytes — the root resolves, the meter honestly reports a
  **shrink**, and every path-based deletion rule waves it through. ⇒ **a VAPORIZE FLOOR**, which judges
  the *outcome* rather than the mechanism and **subsumes all three deletion rules**.
- **D-3 — "fails closed" was FALSE.** `XTTY_GUIDE_CEILING=64K` made `[` error and the gate **ALLOW**
  (`is_int` was never applied to the ceiling); and without `set -E` the ERR trap **never fires inside a
  function or subshell**.
- **D-4 — the unfetched-advertised-OID lane allowed with ZERO measurement.**
- **D-5 — the import grammar did not match the docs**: imports appear **anywhere in a line** (the
  official example is mid-sentence), fenced code is skipped, and a relative path resolves against the
  **containing file**. A `^@`-anchored root-relative parser missed the whole mid-line class — 5,048 B of
  injected content read as 48.

Verified against the real repository: the meter now reads **`81012 ok none`** through `main`'s actual
symlink. The version that survived 11 rounds of review would have read **9**.

## Still open (a design decision, not a bug)

The ceiling is a **ratchet**, and its first notch needs the **compressed draft of `AGENTS.md`** —
which no review round can produce. `XTTY_GUIDE_CEILING` is env-overridable so the fixtures can run
at a scaled-down ceiling.
