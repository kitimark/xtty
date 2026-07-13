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

## Still open (a design decision, not a bug)

The ceiling is a **ratchet**, and its first notch needs the **compressed draft of `AGENTS.md`** —
which no review round can produce. `XTTY_GUIDE_CEILING` is env-overridable so the fixtures can run
at a scaled-down ceiling.
