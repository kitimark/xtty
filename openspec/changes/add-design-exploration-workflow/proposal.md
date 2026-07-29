## Why

xtty's UI has been built feature-by-feature with no place to try a visual direction before writing SwiftUI. The owner wants to draft UI in Open Design (a local-first agent design tool, already installed), starting from a faithful reproduction of what ships today so proposed changes are diffable against a real baseline rather than against memory.

Three prior investigations plus a hands-on POC settled the mechanism (`research/03-analysis/open-design-integration-forensics.md`). The POC also proved the naive approach silently fails: it produced a good-looking mockup whose fidelity came from the agent *opportunistically reading a sibling file*, not from any supported channel — its design system was never selected for the project — indeed, carrying no `metadata.json` it sat `draft` and was not even selectable. Nothing recorded that, so the run looked like a success. This change makes the working path the committed, reproducible one.

## What Changes

- Add a committed `design/` tree: a hand-authored Open Design **design-system package** (`design/xtty-design-system/`) describing xtty's real visual language from its Swift source, and a **project folder** (`design/mockups/`) that is the design agent's working directory. The package directory's basename is load-bearing: the tool derives the design-system id (`user:xtty-design-system`) from it into a flat, machine-global install namespace, so renaming the directory renames the id — and the basename carries the project name so it cannot contest a generic name with another repo's package (design.md D10).
- Add `scripts/design-link.sh` — registers the package with the installed Open Design app **by symlink** (repo bytes == app bytes, so drift is impossible), idempotently, and verifies the registration **by effect** rather than by trusting API responses. Includes a read-only status path and an uninstall path that undoes the whole setup — it deletes the project at `design/mockups/` and the app's workspace copy through the app's own *project*-delete route (verified to resolve only the app's data dir, never the project's `baseDir`), and removes the symlink directly by `unlink(2)` — never through the app's *design-system* delete API, whose behavior on a referenced directory is unverified — with the repo proven untouched by a bracketing `git status design/` byte-compare. Also creates and configures the app-side project — display-named **`xtty`** at creation, working folder `design/mockups/` (dedupe-first by canonical `baseDir` — the app itself never dedupes and names are never identity; creation through the app's bundled first-party CLI, which mints the gated import token internally; an existing project with a different display name is renamed in place, preserving its id and run history; design system + platform chained in the same run, each verified by re-read; printed manual GUI instructions as the fallback).
- Add three self-documenting `make` entry points: `design-link`, `design-status`, `design-unlink`.
- Establish a **baseline-vs-proposal naming contract** for mockups: `<scenario>.baseline.html` reproduces shipped UI (fidelity-only edits, each citing `App/*.swift:line`); `<scenario>.proposal-<slug>.html` is a candidate change. A proposal with no baseline sibling means the feature does not exist in xtty at all — the exact trap the POC fell into with a settings-pane mockup for an app that has no settings UI.
- Establish the **safety posture** as a written contract: the design agent runs `--permission-mode bypassPermissions` with no OS sandbox, so folder scope bounds blast radius without enforcing it. Clean pushed tree before every run; repo-wide `git status`/`diff`/`reflog` after; explicit-path staging only; content telemetry off.
- Record the **linkage lifecycle**, including the one silent failure mode: `tokens.css` propagates live through the symlink but `DESIGN.md` does not — its workspace copy freezes after first sync, so a stale-prose/fresh-tokens state is reachable and invisible.

Not in scope: any change to xtty's shipped UI. Mockups are HTML; Open Design cannot and must not edit Swift. Translation of an accepted direction into SwiftUI is separate work under its own change.

## Capabilities

### New Capabilities
- `design-exploration`: the contract for drafting xtty UI outside the app — what the committed design base must contain and stay true to, how mockups are named and classified (baseline vs proposal), what is committed vs machine-local, the linkage lifecycle, and the safety posture required of an unsandboxed design agent operating inside the repo.

### Modified Capabilities
- `build-workflow`: adds the design-linkage entry points to the documented single-command surface (parallel to how `make install`/`make restart` were added by `add-install-workflow`), including their idempotency, read-only status reporting, and a teardown that undoes the scripted setup — project + workspace via the app's verified-safe project-delete route, the registration reference by direct unlink, never the app's design-system delete path.

## Impact

- **New**: `design/` (design-system package, project folder, `.gitignore`, two READMEs, mockup gallery), `scripts/design-link.sh`.
- **Modified**: `Makefile` (three targets + `.PHONY`).
- **External state, not version-controlled**: a symlink at `<Open Design data>/design-systems/xtty-design-system` → `design/xtty-design-system`, one app-side project row, and one `metadata.json` write-back (the app owns that file's key set and rewrites it wholesale on first run).
- **Depends on**: the installed Open Design desktop app running (the daemon is its sidecar on an ephemeral port; the script never launches it). No new build or test dependencies — the script uses `curl` and the Xcode-provided `/usr/bin/python3`.
- **No effect on**: the app target, `XttyCore`, CI, or any test tier. `design/` is documentation-class content.
