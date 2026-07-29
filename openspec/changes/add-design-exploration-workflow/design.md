## Context

Open Design (nexu-io/open-design) is a local-first design tool, installed as a desktop app (cask `open-design`, v0.16.1). Its generation runtime is the literal `claude` CLI spawned with `--permission-mode bypassPermissions`; its daemon is the app's packaged sidecar on an ephemeral port. It emits **HTML only** — the prompt charter binds the entire preview/export pipeline to HTML, so a `.swift` file the agent wrote would be invisible to it.

Full mechanism, probes, and the retired-theory record: `research/03-analysis/open-design-integration-forensics.md`. The load-bearing findings this design rests on:

- **Only a *selected, published* design system reaches the prompt.** The daemon gates the verbatim paste of the design document and tokens on a non-null, non-draft design-system id (`server.ts:3889-3915`, `prompts/system.ts:1129-1155`). The POC's package had no `metadata.json`, so it was `draft` and not even selectable; its fidelity came from the agent reading a sibling file on its own initiative.
- **`tokens.css` answers to a 56-token schema** (`packages/contracts/src/design-systems/token-schema.ts`) across four layers. Only three font slots exist. The POC bound a `--font-chrome` that is not a token, and its status colours were iOS values, wrong for macOS darkAqua.
- **No OS sandbox.** `OD_SANDBOX_MODE` is refuted — it severs `claude` auth rather than isolating credentials. The POC's agent read a sibling folder outside its project directory unprompted.
- **Content telemetry defaults on**, shipping base64 bodies of produced files. Already disabled on this machine.

xtty's own constraint: it deliberately has almost no visual identity outside the terminal grid. Stock chrome, system-semantic colours, the user's own accent, one bespoke component (a toast). That restraint is the thing a mockup most easily destroys — generic web padding produces a dashboard, not xtty.

## Goals / Non-Goals

**Goals:**
- A design base whose provenance is auditable value-by-value, so nobody later mistakes a platform default or a filled-in slot for an xtty design decision.
- Mockups that reproduce shipped UI first, so proposals are diffable against something real.
- Linkage that is scripted, idempotent, and verified by effect — the POC's failure was invisible precisely because nothing checked the effect.
- A safety posture written where it will actually be read, given an unsandboxed agent inside the repo.

**Non-Goals:**
- Changing xtty's shipped UI. Translating an accepted mockup into SwiftUI is separate work.
- Automating the design tool's GUI. No native-macOS automation exists in this environment. (Project creation and picker selection were originally scoped as human steps for this reason; both are now scripted — creation through the tool's bundled first-party CLI, selection through its ungated PATCH route — which automates the *outcome* without driving the GUI. The GUI remains the documented fallback, not an automation target.)
- Committing app-side state (its database, run traces, config). Only the repo half is portable.
- A components fixture. Deferred until the first mockups exist to distil one from — and `manifest.json` accordingly declares no `components` entry: the tool silently ignores a declared-but-missing file at every consumer, so a dangling key would be a dead promise, not a working declaration (owner review, 2026-07-29).

## Decisions

### D1 — Symlink registration, not copy or folder-import

`POST /api/design-systems/install` with `{"source":"local","path":…}` symlinks the tool's catalogue entry at the repo directory (`library-install.ts:175`; discovery honours symlinks at `design-systems/index.ts:277`). Repo bytes and app bytes become the same bytes, so drift is structurally impossible rather than merely unlikely.

*Alternatives:* a copy (drift by construction, and the POC's ambiguity about whether its install was a copy or a link is exactly the confusion to avoid); `POST /api/design-systems` writing the body verbatim (works, but stores a second copy); **"Import from folder" — rejected outright**, it is the CSS/JS scanner and would regenerate the design document from a scan of a directory containing no CSS, destroying the authored prose.

### D2 — Verify by effect, never by API echo

Every check reads the filesystem or the tool's catalogue after the fact; the closing check is that a value unique to our tokens appears in freshly generated output. A configuration read is a **precondition only**: the project's stored design-system id still reads correctly when the symlink dangles or the package regresses to draft, while the daemon composes zero design blocks. That exact gap is what made the POC look successful.

### D3 — Provenance tags in the artifact, not in a side note

Each token declaration carries `M` (measured, cited `path:line`), `P` (platform-resolved, probe-measured), or `D` (derived, filling a required slot). The tags live inline because the file is pasted verbatim into the agent's prompt — a provenance note kept elsewhere would not travel with the values it governs. Rule: a flat hex may carry `M` only if that hex appears in xtty's source.

### D4 — Baseline/proposal encoded in the filename, and asserted in the page

`<scenario>.baseline.html` vs `<scenario>.proposal-<slug>.html`. `b` sorts before `p`, so every listing shows a baseline above its proposals. A proposal with no baseline sibling means the feature does not exist in xtty — and because a filename is invisible once the page is open, that class also declares itself in the rendered page. The POC's settings-pane mockup was exactly this and nothing anywhere said so.

### D5 — Ignore rules live at `design/`, one level above the agent's working directory

The agent runs unsandboxed with its cwd at `design/xtty-mockups/`. Rules placed inside that directory could be rewritten as an ordinary in-scope edit; placed one level up, the same rewrite requires leaving project scope — a loud, reviewable event. Rules are annotated per entry with the reason, and anything unclassified stays visible in `git status` deliberately, as a tripwire.

One consequence must be handled explicitly: an ignore rule hides the file it names, so a marker whose *existence* signals a broken state becomes invisible to status. Those are checked by an explicit existence test in the post-run checklist instead.

### D6 — `metadata.json` authored to the app's own key set

The daemon rewrites that file wholesale on first run as a 9-key allowlist; any other key is silently deleted. Authoring exactly those keys (minus the one the app supplies) collapses the first-run diff to a single added line, which can then be committed deliberately rather than investigated.

One of those keys is held deliberately against intuition: `surface` stays `"web"` even though xtty is a macOS app. The schema's only legal values are `web | image | video | audio` — no desktop/native value exists — and the field names the **artifact medium**, not the product platform: it drives the tool's design-systems catalog filter and the exported SKILLS.md framing, and never reaches the generation prompt (media-vs-HTML dispatch keys on the *project's* surface). The tool emits HTML only, so `web` is the honest value; the macOS targeting is carried by the project's `platform: "desktop-app"`. An unrecognized value would be silently dropped by the metadata reader and fall back to `web` anyway (owner review, 2026-07-29; schema evidence in the forensics doc, addendum (e)).

### D7 — Scenario coverage stops at xtty's authored pixels

Twelve baselines cover every surface xtty actually draws. Past that the mockups would be drawing macOS, not xtty. Three surfaces are excluded even as proposals: a project file-tree browser (a standing refutation), any account or sync chrome (a hard product requirement), and an app icon (none exists to reproduce).

### D8 — The script owns what is scriptable and says what is not *(revised: everything is now scriptable)*

As first shipped: registration, verification, status, and teardown were scripted; project creation was believed to require the GUI because `POST /api/import/folder` is HMAC-gated (measured live: 403 `token missing` without a token bound to the path), and the script printed the GUI import as an explicit next step.

Revised 2026-07-29: the belief was wrong — the gate is real, but the installed app ships a first-party CLI (`od project import-folder`, run through the bundled Electron helper) that mints the gated token itself over the daemon's IPC socket. Creation is now scripted through that CLI: dedupe-first by `realpath(baseDir)` (the tool itself never dedupes — two projects at the same directory are representable and were observed), verified by effect (re-read shape `importedFrom:"folder"` + `fromTrustedPicker:true` + canonical `baseDir`; `git status design/` unchanged across the import), then chained into the existing selection flow. The gate is *satisfied*, never bypassed — the script reads only public process metadata to locate the socket and never mints tokens or touches secrets itself; if the CLI route fails, the printed manual GUI instructions remain the documented fallback. Creation auto-runs from the default install flow because dedupe-first makes it idempotent and every failure degrades to exactly the old behavior.

*Consequence accepted knowingly:* `fromTrustedPicker: true` is stamped for any valid token regardless of origin, so once creation is scripted the flag attests "a valid HMAC was presented", not "a human chose this folder in the native picker" (see Risks).

### D9 — The project is display-named `xtty`; identity stays the canonical base directory *(added 2026-07-29, owner call)*

The app-side project is named **`xtty`**, not after its folder. The project folder is `design/xtty-mockups/` (first shipped as `design/mockups/`; renamed 2026-07-29 on an owner consistency call so the `design/` tree reads with one `xtty-*` prefix beside the package folder) and the name/folder mismatch is accepted. It is sound because the name is pure display in the tool — it labels the project list, the export archive filename, and the seeded conversation title; it never reaches the agent's prompt, never keys an artifact path (folder-backed projects write into `baseDir`), and the script resolves projects exclusively by `realpath(metadata.baseDir)`.

Unlike the package basename (D10), the mockups basename carries **no identity** — verified in source when the folder was renamed: the display name falls back to `basename(baseDir)` only when the import sends no name (the script always sends `--name`), `entryFile` is stored relative and re-detected per import, export filenames derive from the title, and run records reference the project id, never the path. What the rename *does* hit is the stored `baseDir` itself: it is absolute and **immutable after import** — the tool's update route rejects any re-point ("baseDir is immutable after import; use a new import to change it") and its CLI has no move verb — and teardown resolves its target by that same stored path. So a mockups-folder rename is executed teardown-first (`make design-unlink`, then `git mv`, then `make design-link` recreates the project via a fresh import), and the only cost is the old row's app-side run/chat history (zero at the time of the rename).

Mechanics: the name is set **at creation** (the bundled CLI's `--name`; the import route only falls back to `basename(baseDir)` when no name is sent) and **converged in place** on an existing row via the tool's ungated project-update route, verified by re-read — preserving the row's id and run history, where delete-and-recreate would not. `--design-system` is deliberately *not* folded into the import call: the import rejects outright on a missing/draft package, which would replace the recoverable created-but-half-configured state with no project at all, and the platform update must run separately anyway.

Two hazards were checked and are accepted: (1) the tool's rename write-through — a project rename propagating into the bound design system's `metadata.json`, which for us is the symlinked repo file — is gated on `importedFrom: "design-system"` and cannot fire for our `"folder"`-imported project (proven in source and by a bracketing `git status` compare); the inverse warning is documented — never rename the `ds-xtty-design-system` workspace row in the app, because for *that* row the write-through does fire and reaches the git tree. (2) The workspace row displays the design system's title, so the project list can show two rows reading "xtty"; the by-name `--select-project` matcher narrows name collisions by `baseDir` before failing as ambiguous.

### D10 — The package directory is `design/xtty-design-system/`; its basename **is** the design-system id *(added 2026-07-29 as `design/design-system/`, an owner readability call; revised the same day on owner review — uniqueness wins over brevity)*

The committed package lives at `design/xtty-design-system/`. The basename is identity-bearing, not cosmetic, because the tool offers no way to decouple the id from the path: the install body is only `{source, path}`, the symlink is created at `<data>/design-systems/<basename(realpath)>` (`library-install.ts:162-180`), and the catalog id is always `user:<entry-name>` from a bare readdir (`design-systems/index.ts:269-310`) — so the directory name fixes the id at **`user:xtty-design-system`**. Decoupling was re-confirmed impossible on the second rename: no install-body field, no manifest override.

The name moved twice, both deliberate. First `design/xtty/` → `design/design-system/`, purely so the tree read as `design-system/` + `mockups/` (readability). The owner's review then flagged what that generic basename costs: `<data>/design-systems/` is a **flat, machine-global namespace keyed by basename**, so `design-system` is a name any other repo's package directory can equally claim — the install route refuses the second claimant (`installFromLocal`'s collision check 400s "already installed", `library-install.ts:164-171`), which is loud but first-come-first-served. Hence the second rename to `xtty-design-system`: carrying the project name makes the installed identity unique by construction, retiring the collision instead of accepting it. This knowingly walks back part of the earlier readability rationale — uniqueness wins over brevity. The id is still not user-facing (the picker displays the *title*, `xtty`, from `metadata.json`), so UI readability is unaffected either way.

Every such rename is an id migration, executed old-id-first (the script derives every teardown target from the basename, so teardown must run before `git mv`), and two identity-coupled values move with it: (1) `manifest.json`'s `id` must equal the new basename — the manifest validator rejects on mismatch and the whole manifest is then *silently ignored* (`isProjectManifest`, `design-systems/index.ts:3683-3702`), costing the picker subtitle and category; (2) the app-written `metadata.json` `projectId` must be dropped in the rename commit rather than hand-rewritten, because the workspace-ensure path *prefers* a recorded `projectId` over deriving `ds-<basename>` (`projectBackedDesignSystemProjectId`) — a stale committed id would be reused forever and orphaned from the script's `ds-<pkg>` teardown; the app re-mints `ds-xtty-design-system` on first workspace ensure and that write-back is committed deliberately.

### D11 — The mockups folder ships flat: no `assets/` directory *(added 2026-07-29, owner-delegated decision settled by source investigation)*

The original scaffold carried an empty `design/xtty-mockups/assets/` (a `.gitkeep` placeholder for mockup images). It is dropped, because every path that could ever put an image there was measured shut in the tool's source (@ f52fda2):

- **Media generation cannot reach the repo.** Both media routes (`/api/projects/:id/media/generate`, `/api/tools/media/generate`) funnel into `generateMedia`, which resolves its write directory **without the project's metadata** (`media/index.ts:450` calls `ensureProject(projectsRoot, projectId)` with no metadata argument), so `resolveProjectDir` never sees `baseDir` and output always lands flat in the app-side data dir (`<data>/projects/<projectId>/`) — for every project shape, folder-backed included. The output filename is flattened (`sanitizeName` maps `/` and `\` to `_`, `projects.ts:1434`), so a subdirectory cannot even be requested. The FileViewer's read path *does* thread metadata, so for a folder-backed project the write and read paths disagree — the tool has no working image pipeline into `baseDir` at all.
- **Uploads land flat.** The chat upload route threads metadata (files do land in `baseDir`), but raw multipart names are plain basenames at the project root; only the design-kit brand uploader passes subdirectory paths, and its convention is `imagery/`, not `assets/` (`routes/project/index.ts:3704-3717`).
- **The bundled `web-prototype` skill mandates a single self-contained HTML artifact** with `.ph-img` placeholder classes ("Image placeholders, not external URLs"); its own `assets/` references are to its bundled seed template inside `.od-skills/`.
- **Our conventions already prohibited what the directory implied**: a mockup referencing `assets/foo.png` would break the self-contained/no-external-requests rule in `README.md` and `USAGE.md`. The self-contained answer, if an image is ever unavoidable, is a data URI — now stated on both agent-visible surfaces.
- **The directory was itself the mis-import hazard.** Neither folder-picker implementation pins a default path (Electron `showOpenDialog` without `defaultPath`, `runtime.ts:1875-1890`; the daemon's osascript `choose folder` without `default location`, `server.ts:1685-1705`), so the panel opens at per-app remembered state — and `assets/`, the only visible subdirectory, is where the remembered-state panel once rooted a project one level too deep (`baseDir=…/assets`). "The panel defaults into a subdirectory" is refuted as designed behavior and confirmed as a stateful hazard class; dropping the directory removes the GUI-fallback route's only capture point.

If a mockup ever genuinely needs a real image file, that is the moment to design its home with the tool's measured behavior in hand — not before. Evidence and probes: forensics doc, addendum (g).

## Risks / Trade-offs

- **The agent can reach the whole repo** → folder scope bounds blast radius without enforcing it. Mitigation is detect-and-revert: clean *pushed* tree before every run, repository-wide status/diff/reflog/stash review after, explicit-path staging. Accepted deliberately in exchange for mockups being a git-tracked deliverable; the alternative that removes rather than bounds the risk is an out-of-repo folder.
- **A stale design document with fresh tokens, silently** → the tokens file propagates through the symlink (mtime-fingerprinted); the design document does not — its workspace copy freezes after first sync. Mitigation: the lifecycle documents clearing that cache after every prose edit, and the closing check is a generated-output grep, which catches the stale state.
- **Values that are platform, not xtty** → roughly a third of the schema slots have no xtty literal. Mitigation is D3: they ship tagged, so a future reader cannot cite them back as xtty facts.
- **Content telemetry has no rollback and no detection** → there is no local send-log, so what past runs transmitted is unrecoverable. Prevention-only; the checklist verifies the setting on disk before runs rather than implying it can be audited after.
- **Teardown could reach the working tree** → the app's *design-system* delete path does a recursive remove on the catalogue entry, and whether that unlinks a top-level symlink or recurses into the repo is unverified. Never exercised; teardown removes the link by hand. The app's *project* delete route is a different mechanism with a verified-safe target (`removeProjectDir` resolves only the app's own data-dir project folder, never `baseDir`) — teardown uses it for the project at `design/xtty-mockups/` and the workspace copy, and proves the repo untouched with a `git status design/` byte-compare bracketing the whole run.
- **HTML cannot reproduce AppKit exactly** → SF Mono is not web-available, and the quake surface is sized from the screen's visible frame rather than a viewport. Accepted as approximation, annotated where it bites.
- **Repository growth** → mockups run ~40 KB each. Mitigation: commit per *accepted* iteration, not per run; the agent's revision copies are promoted-and-deleted before commit rather than accumulating.
- **Scripted creation redefines `fromTrustedPicker`** → the flag now attests only that a valid HMAC token was presented, not that a human chose the folder in the native picker. Accepted knowingly by the owner; recorded plainly in `design/README.md` so the flag is never later read as an audit trail of human consent.
- **Two rows can display "xtty" in the tool's project list** (D9) → the renamed project and the `ds-xtty-design-system` design-system workspace row, which mirrors the design system's title. Display-only ambiguity, accepted; the repo-reaching edge — renaming the *workspace* row writes the title through the symlink into `design/xtty-design-system/metadata.json` — is documented as a never-do in `design/README.md`, and the project's own rename is proven unable to do that.
- **~~A generic package basename occupies a global name~~ (D10) — retired 2026-07-29 by the owner review**: while the package was named `design-system`, any other repo installing a same-named package directory would have contested the flat, basename-keyed install namespace (loud 400, first-come-first-served). The rename to `xtty-design-system` removes the collision by construction rather than accepting it; the residual risk is only the general one every identity rename carries — the migration ordering D10 records.

## Migration Plan

Additive; nothing existing changes behavior. Rollback is `make design-unlink` plus deleting `design/`, `scripts/design-link.sh`, and the Makefile targets — the external state is the app-side symlink, the project row at `design/xtty-mockups/`, and the `ds-` workspace copy, and `design-unlink` removes all three (the tool is left as it was, modulo run-history dirs the app's own delete also leaves and the stale UI card until relaunch).

Ordering matters in one place: the package must be authored and committed **before** linkage, since the symlink resolves a real directory; and linkage must precede the project's design-system selection, since the picker can only offer a registered, published package. (Project creation itself — scripted via the bundled CLI, or the GUI folder picker as fallback — has no linkage dependency; the chained design-system selection is what requires the registered, published package first.)

## Open Questions

- ~~Whether the tool's interface exposes the symlink-install route at all.~~ **Settled 2026-07-29:** it does not — the script is the only safe path; the interface's "Import from folder" for design systems is the destructive scanner. Recorded in `design/README.md`.
- ~~Whether the interface offers the design-system picker for a folder-linked project.~~ **Settled 2026-07-29:** it does (home composer and per-project), and the channel was proven by effect — a sentinel token value appeared in generated output. Recorded in `design/README.md`.
- ~~Whether project creation can be scripted at all.~~ **Settled 2026-07-29 (reversing the original assumption):** the HTTP route is HMAC-gated as believed, but the app's bundled first-party CLI mints the token itself — creation is scripted via that CLI with the GUI as fallback (D8, revised).
- Whether `.listStyle(.sidebar)` engages an AppKit material in xtty's bare-hosted sidebars. This decides whether mockup panels paint as a flat surface or a distinct tier, so it is worth one screenshot before authoring the first baselines.
- Whether the artifact sidecars the tool writes churn their timestamps on unchanged regeneration. If they do, committing them is noise and they should move to the ignore list.
