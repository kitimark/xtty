# design/ — drafting xtty's UI in Open Design

A place to try a visual direction before writing SwiftUI. Two halves:

| | What it is | How it reaches the app |
|---|---|---|
| `xtty/` | The **design-system package** — xtty's visual language, hand-authored from Swift source | Symlinked into Open Design by `make design-link`. Repo bytes *are* app bytes. |
| `mockups/` | The **project folder** — the design agent's working directory | Imported once through the app's folder picker. |

Open Design emits **HTML only**. Its coherent role here is mockup exploration; translating an accepted direction into SwiftUI is separate, human work. It cannot and must not edit Swift.

Background, mechanism, and the retired theories: `research/03-analysis/open-design-integration-forensics.md`.

## Setup

```sh
make design-link      # register the package (idempotent; needs the app running)
make design-status    # read-only linkage report
make design-unlink    # remove the app-side symlink by hand
```

Then, in the app — these two steps cannot be scripted:

1. **New project → import folder →** `design/mockups/`
2. **Set the project's design system to `xtty`.**

Step 2 is not optional decoration. It is the *only* channel that pastes `tokens.css` and `DESIGN.md` into the agent's prompt. A package that is registered but not selected — or selected but not published — contributes **nothing**, and the agent may still produce plausible-looking output by reading files on its own. That is exactly how an earlier attempt looked successful while being wired up wrong.

**Verify by effect, not by configuration.** Change one token value, run one generation, grep the output for the new value. Reading the stored design-system id proves only a precondition: it still reads correctly when the symlink dangles or the package has regressed to draft.

## The naming contract

- `<scenario>.baseline.html` — reproduces what ships **today**, citing `App/*.swift:line`. Edited only to become more faithful. Never renamed or deleted.
- `<scenario>.proposal-<slug>.html` — a candidate change. Free to add, revise, delete.
- **A proposal with no baseline sibling means the feature does not exist in xtty**, and the page must say so visibly.

`b` sorts before `p`, so every listing shows a baseline above its proposals.

**Revision copies** (`*-v2.html` and friends) are run-local scratch. They are deliberately **not** gitignored — hiding them would let the good revision sit in an invisible file while `git status` reads clean. Before committing: promote the winner over the canonical filename, delete the rest, then add or refresh its card in `mockups/index.html`. Rejected proposals get deleted; git is the archive.

## Update lifecycle

| File | Propagates | Notes |
|---|---|---|
| `xtty/tokens.css` | **Automatically** | Read fresh through the symlink every run |
| `xtty/USAGE.md` | **Automatically** | Same — put iterating rules here |
| `xtty/DESIGN.md` | **No** | The picker copies it into a workspace once and that copy **freezes** |

To force a `DESIGN.md` re-copy: `rm -rf "<Open Design data>/projects/ds-xtty/"`, then run one generation.

**Skipping that yields fresh token values with stale prose, with no error shown anywhere.** It is the one silent failure mode in this setup. `make design-status` reports the workspace-copy state; catch it there, or catch it by grepping generated output for a phrase you just changed.

Moving or renaming this checkout dangles the symlink silently — re-run `make design-link`, which detects and repairs it.

## Portable vs per-machine

**In git:** everything under `design/`. **Not in git, and re-created by re-running the setup above:** the symlink, the app's project row, and its config. A fresh clone on another machine needs `make design-link` plus the two GUI steps — nothing else.

`manifest.json`'s `source.path` is repo-relative and provenance-only; no code branches on it.

## Safety posture

The design agent runs as `claude --permission-mode bypassPermissions` with **no OS-level sandbox**. Scoping it to `mockups/` bounds the blast radius; it does not enforce a boundary — a previous run's agent read a sibling folder outside its project directory unprompted. `OD_SANDBOX_MODE` is not a fix: it severs the CLI's authentication rather than isolating it.

So the posture is **detect and revert**:

**Before any run**
- Working tree clean *and pushed*. This removes the one failure mode with no rollback — an errant `git clean` on untracked files.
- Content telemetry off. Verify **on disk**, not in the UI: `telemetry.content` must read `false` in the app's `app-config.json`. The default ships your prompt, the agent's output, bash stdout, and **base64 bodies of produced files** to a remote relay. There is no local send-log, so this is **prevention-only** — it cannot be audited or undone after the fact.

**After every run**
```sh
git status                    # repo-wide, not just design/
git diff
git reflog -10                # destructive git leaves a clean-looking tree
git stash list
test -e design/xtty/.od-generated.json && echo 'ARTIFACT MODE LOST'
```

That last line is not redundant. `.gitignore` hides that file, so `git status` can no longer reveal it — and its mere existence means the package lost `agent-managed` mode and the app is about to scaffold over the authored files.

**Committing:** stage by explicit path. Never `git add -A` after a run.

**When done:** quit Open Design fully and confirm with `ps` — a run can finish with the app still believing it is in flight.

## What the interface actually exposed

*(To be filled in after the first live setup — whether the symlink-install route and the design-system picker were reachable through the GUI at all, or whether the script is the only path. Recorded here because it is the highest-value unknown in this setup.)*
