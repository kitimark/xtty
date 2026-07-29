# design/ — drafting xtty's UI in Open Design

A place to try a visual direction before writing SwiftUI. Two halves:

| | What it is | How it reaches the app |
|---|---|---|
| `design-system/` | The **design-system package** — xtty's visual language, hand-authored from Swift source | Symlinked into Open Design by `make design-link`. Repo bytes *are* app bytes. The directory basename **is** the design-system id (`user:design-system`) — the install route derives the symlink name and catalog id from it, and `manifest.json`'s `id` must equal it or the manifest is silently ignored. Renaming this directory renames the id; re-run the full unlink → link cycle. The picker shows the *title* (`xtty`, from `metadata.json`), not the id. |
| `mockups/` | The **project folder** — the design agent's working directory | Imported once by `make design-link` via the app's bundled CLI (GUI folder picker is the fallback). The app-side project is *named* **`xtty`** (display only — see the naming note below); the folder stays `mockups/`. |

Open Design emits **HTML only**. Its coherent role here is mockup exploration; translating an accepted direction into SwiftUI is separate, human work. It cannot and must not edit Swift.

Background, mechanism, and the retired theories: `research/03-analysis/open-design-integration-forensics.md`.

## Setup

```sh
make design-link      # register the package + create/configure the 'xtty' project (idempotent; needs the app running)
make design-status    # read-only linkage report
make design-unlink    # undo design-link: delete the 'xtty' project + workspace copy, unlink the symlink (idempotent)
```

`make design-link` now does the whole setup: it registers the package, then creates the **`xtty`** project (named at import via `--name`; working folder `design/mockups/`) through the app's **bundled first-party CLI** (`od project import-folder`, run via the app's own Electron helper — it mints the gated import token itself; the script never touches the daemon's socket or secrets) and points it at the `xtty` design system. It dedupes by `baseDir` first, so re-running is a no-op that reports the existing project — and if the existing project carries a different display name (a GUI import defaults to the folder name `mockups`), it renames it in place, keeping its id and run history. If any of that fails, the script prints the manual GUI steps, which remain the documented fallback:

1. **New project → "Open folder" →** `design/mockups/`
2. **Re-run `make design-link`** — it renames the GUI import to `xtty` and sets design system + platform (or set the design system by hand in the picker).

> **The naming note.** The project's *name* is `xtty`; its *folder* is `design/mockups/` (the folder is the agent's working directory; keeping the generic folder names — `design-system/` for the package, `mockups/` for the working folder — is an owner readability call). That mismatch is deliberate and harmless: the name is pure display — it labels the app's project list and export filenames, never reaches the agent's prompt, and keys nothing (identity everywhere, in the app and in the script, is `realpath(baseDir)`). Two caveats it buys: (1) once the app has ensured the design-system *workspace* row (`ds-design-system`), the project list shows **two rows displaying "xtty"** — that row mirrors the design system's title; the one whose card opens `design/mockups/` is the project. (2) **Never rename the `ds-design-system` workspace row in the app** — a rename on a workspace row writes the new title through into the design system's `metadata.json`, which is our symlinked `design/design-system/metadata.json`, i.e. an app-initiated write into the git tree. Renaming the `xtty` project itself cannot do that (verified: the write-through is gated on `importedFrom:"design-system"`; ours is `"folder"`).

Step 2 is not optional decoration. It is the *only* channel that pastes `tokens.css` and `DESIGN.md` into the agent's prompt. A package that is registered but not selected — or selected but not published — contributes **nothing**, and the agent may still produce plausible-looking output by reading files on its own. That is exactly how an earlier attempt looked successful while being wired up wrong.

> **What `fromTrustedPicker` means now.** The import route stamps `fromTrustedPicker: true` for **any valid HMAC token**, regardless of origin. While creation was GUI-only, that flag genuinely meant "a human chose this folder in the native picker". With creation scripted through the app's own CLI, it means only "a valid token was presented". The gate itself still stands (a bare `POST /api/import/folder` without a token is still 403), but the flag no longer carries human-consent semantics. Owner-accepted tradeoff, recorded here so nobody later reads the flag as an audit trail of human choices.

**Verify by effect, not by configuration.** Change one token value, run one generation, grep the output for the new value. Reading the stored design-system id proves only a precondition: it still reads correctly when the symlink dangles or the package has regressed to draft.

## Teardown

`make design-unlink` undoes everything `make design-link` set up: it deletes the `xtty` project at `design/mockups` (resolved by canonical `baseDir`, never by name; via the ungated project-delete route — the same route the app's own CLI uses; refuses with more than one match), removes the `ds-design-system` workspace copy (row + directory), and removes the symlink by hand — `unlink(2)`, never the app's design-system delete route, whose recursive behavior on a referenced directory remains deliberately unverified. Every removal is verified by re-read, the whole run is bracketed by a `git status design/` byte-compare, and re-running on a clean state is a no-op. `--keep-project` preserves the project row (and its app-side run history) while removing the rest; project deletion never touches `design/mockups/` — the mockups live in the repo, so the only thing deletion costs is app-side run/chat history.

Three things teardown does **not** do: it cannot delete the project row while the app is not running (it then does the filesystem half — symlink, workspace directory — reports what it skipped, and exits 2; relaunch and re-run to finish); it leaves finished run directories under the app's `runs/` in place (the app's own delete leaves them too — the script reports how many reference the deleted project); and it cannot refresh the running app's UI — **after any teardown, the open app still shows a phantom card for the deleted project until you quit and relaunch** (the in-app Refresh does not clear it; see the hazards below).

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

To force a `DESIGN.md` re-copy: `rm -rf "<Open Design data>/projects/ds-design-system/"`, then run one generation.

**Skipping that yields fresh token values with stale prose, with no error shown anywhere.** It is the one silent failure mode in this setup. `make design-status` reports the workspace-copy state; catch it there, or catch it by grepping generated output for a phrase you just changed.

Moving or renaming this checkout dangles the symlink silently — re-run `make design-link`, which detects and repairs it.

## Portable vs per-machine

**In git:** everything under `design/`. **Not in git, re-created by `make design-link` and removed again by `make design-unlink`:** the symlink, the app's project row, and its config. A fresh clone on another machine needs `make design-link` — nothing else (the two GUI steps are only the fallback if the scripted creation fails).

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
test -e design/design-system/.od-generated.json && echo 'ARTIFACT MODE LOST'
```

That last line is not redundant. `.gitignore` hides that file, so `git status` can no longer reveal it — and its mere existence means the package lost `agent-managed` mode and the app is about to scaffold over the authored files.

**Committing:** stage by explicit path. Never `git add -A` after a run.

**When done:** quit Open Design fully and confirm with `ps` — a run can finish with the app still believing it is in flight.

## What the interface actually exposed

*Settled 2026-07-29 by driving the GUI (peekaboo) and reading `app.sqlite` after each step. Amended the same day: manual import is no longer the only route.*

**In the GUI, use "Open folder". It is the only GUI route that puts mockups in this repo** — the New project dialog offers three storage-ish affordances and they produce three different project shapes, only one folder-backed:

| Route | `metadata_json` | Where artifacts land |
|---|---|---|
| **New project → "Open folder"** | `baseDir`, `importedFrom:"folder"`, `entryFile`, `fromTrustedPicker:true` | **The folder — in this repo.** ✅ |
| New project → "Local storage" | `userWorkingDir` | App's data dir. Recorded as a preference; does not become the agent's cwd. |
| Home composer → "Select working directory" | `linkedDirs` | App's data dir. Its own tooltip says it: *"Let the agent read this local folder (not imported into Design Files)."* |

Two of the three look like what you want and are not. Verify after creating: the project's `metadata_json` must contain `baseDir`.

**But the GUI is no longer required at all**: the app ships a first-party CLI (`od project import-folder`, at `Contents/Resources/app/prebundled/daemon/daemon-cli.mjs`, runnable through the bundled Electron helper with `ELECTRON_RUN_AS_NODE=1`) that produces the exact same folder-backed shape, HMAC token and all. `make design-link` uses it; verified by effect — identical `metadata_json` (`importedFrom:"folder"`, `fromTrustedPicker:true`, realpath'd `baseDir`), zero bytes written into the imported folder. See the `fromTrustedPicker` semantics note in Setup above.

**Two operational hazards, both measured 2026-07-29:**

- **Open Design does not dedupe folder imports.** The import route has no existing-project check and the `projects` table constrains only `id` — not `name`, not `metadata.baseDir`. Importing the same directory twice yields two independent projects writing into the same folder, each with its own design-system setting, and nothing warns at import time; a generation run in the unconfigured one silently skips our tokens. This is why the script dedupes by `realpath(baseDir)` before creating, and why `make design-status` warns when more than one project points at `design/mockups`.
- **Deleting a project via the HTTP API (or the CLI, same route) leaves a phantom card in the app's UI** that the in-app "Refresh" button does **not** clear — only quitting and relaunching does (DB and disk had one project while the UI showed two). Delete projects in the app, or expect to relaunch after an API delete — `make design-unlink` deletes over the API and prints this exact reminder after every daemon-side delete.

Other findings from that first run:

- **The design-system picker is exposed**, both on the home composer and per-project (the palette chip above the prompt box). `xtty` appears under **YOUR SYSTEMS**, above the bundled presets, with our `manifest.json` description as its subtitle. Selecting it set `design_system_id` to the package id (`user:xtty` at the time; `user:design-system` since the 2026-07-29 package-directory rename).
- **The symlink-install route is not exposed in the UI** as far as could be found — `make design-link` is the path. The UI's "Import from folder" for design systems remains the destructive scanner; do not use it.
- **`index.html` pinned `entryFile` at import**, as intended. Create it before importing.
- **Import wrote zero bytes** into the repo, confirmed by checksum before/after.
- **The channel was proven by effect**: a sentinel token value edited in `tokens.css` appeared in the generated HTML minutes later, and the agent's own summary cited our `DESIGN.md` sections by number.
- **`metadata.json`'s `provenance` must be an object** (`notes`, `localCodeFiles`, `sourceUrls`, …), not a string. A string is silently dropped on the app's write-back.
- Deleting a project via the app never touches `baseDir` — verified by checksum, and in source (`removeProjectDir` resolves the app's own project dir only).
- A Finder panel can leave a `.DS_Store` in the project folder; it is ignored repo-wide already.
