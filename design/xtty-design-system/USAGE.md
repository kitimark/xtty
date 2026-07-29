# Using the xtty design system

This file is injected **above** `DESIGN.md` in the design agent's prompt.

**Why the rules that change live here.** `tokens.css` and this file are re-read through the symlink on every run, so edits land immediately. `DESIGN.md` is **not** — the picker copies it into a workspace once and that copy freezes, so an edit there does nothing until the workspace copy is cleared. Put anything you expect to iterate on *here*; keep `DESIGN.md` for the stable description of what xtty looks like.

## Before you draw anything

Read `README.md` in the project root. It names the scenario you are drawing and whether it is a **baseline** (reproduce what ships) or a **proposal** (a candidate change).

## The three rules that matter most

1. **Every color comes from a token.** No raw hex outside `:root`. Terminal content — prompts, `ls` output, diff text — uses `--xtty-ansi-0` … `--xtty-ansi-15`. If a value you need is missing, say so and propose a new token; never invent one inline. An invented value is indistinguishable from a measured one once it is in the markup.

2. **Spacing is 2px-dense.** Reach for `--space-1` (2px) and `--space-2` (4px) before `--space-4` (8px). Web-default padding is the single fastest way to make a mockup stop looking like xtty.

3. **A baseline cites its source.** Every measurement you draw in a baseline should trace to an `App/*.swift:line` reference from `DESIGN.md`. If you cannot find the citation for something, that is a signal you are inventing it.

## Token binding notes that are easy to get wrong

- **`--text-base` (11px) is not body copy.** It is the glyph/diff-row size. Body copy — notably the sidebar's pane label — is `--text-xl` (13px), because an unmodified SwiftUI `Text` renders at default body size.
- **`--accent` is a stand-in.** xtty uses the user's own macOS accent. Render it blue; never describe blue as xtty's brand color.
- **The git panel is 280pt** (`--xtty-git-panel-w`). The 240 (`--xtty-git-panel-min-w`) is a content minimum on a different layer — do not lay out at 240.
- **`--elev-raised` is `none` on purpose.** Do not substitute a shadow because a card "looks flat". Flat is correct.
- **The sidebar and git-panel file list are a live AppKit material — paint them flat.** On screen they mix the desktop behind the window (and saturate it ~2×); a mockup cannot reproduce that and must not try. Fill them with `--xtty-panel-bg` (active window) or `--xtty-panel-bg-inactive` (inactive), use `--surface` for the titlebar and the git panel's empty states (those are opaque — the material only exists where a List paints), and annotate the vibrancy where it matters. **Never use `backdrop-filter`**: the mockup's backdrop is the page, not the user's wallpaper, so it would blur-and-tint the wrong thing.
- **The window is 900×560 of *content*.** The titlebar is above that; do not subtract it from the 560.

## Output conventions

- One self-contained HTML file per scenario. Inline CSS, no build step, no external requests.
- No image files. If a scenario genuinely cannot be shown without an image, inline it as a data URI — the project folder has no `assets/` directory, and a mockup must not reference sibling files.
- Zero JavaScript unless a scenario genuinely cannot be shown without it — these are static mockups, not prototypes.
- Where a scenario has several states that share a layout (empty / loading / populated / error), show them as labeled variants **in the same page**. Only split into separate files when the layout itself differs.
- Annotate any place where HTML cannot faithfully reproduce AppKit — approximate font metrics, the viewport-vs-visible-frame difference on the quake surface — rather than silently drawing something slightly wrong.

## Never touch

`index.html` and `README.md` in the project root are hand-maintained. Do not edit, reformat, or "improve" them.
