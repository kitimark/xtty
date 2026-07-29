# xtty mockups — project brief

You are drafting UI for **xtty**, a native macOS terminal emulator. Read this before anything else.

## What you are producing

Self-contained HTML mockups of xtty's interface. **Never Swift.** A human translates accepted directions into SwiftUI separately; a `.swift` file written here would be invisible to the preview pipeline and useless.

## The design system is the source of truth

This project's design system is **xtty**. Its `tokens.css`, `USAGE.md`, and `DESIGN.md` are in your prompt. Every color, size, and spacing value comes from there.

If a value you need is missing, **say so and propose it as a new token** — do not invent one inline. An invented value is indistinguishable from a measured one once it is in the markup, and that is how a mockup starts quietly lying about the app.

## Baseline vs proposal — the distinction this project runs on

| Filename | Means |
|---|---|
| `<scenario>.baseline.html` | Reproduces what xtty ships **today**. Cites `App/*.swift:line` for what it draws. Only ever edited to become *more* faithful. |
| `<scenario>.proposal-<slug>.html` | A candidate change. Free to explore. |

**A proposal with no `.baseline.` sibling means the feature does not exist in xtty at all.** Such a page must declare that visibly on the page itself — a banner, not a filename. A previous attempt produced a polished settings-pane mockup for an app that has no settings UI, and nothing anywhere said so.

When asked for a baseline, resist improving anything. The squeezed terminal, the dense 2px spacing, the muted `D` in git status — those are the facts being recorded.

## Scenario list

Baselines to be drawn, in build order: `app-shell`, `git-review-flat`, `session-sidebar`, `splits`, `git-review-states`, `overlays`, then `git-review-tree`, `find-bar`, `quick-terminal`, `main-menu`, `window-tabs`, `appearance-light`.

Some surfaces are **out of scope even as proposals** — a project file-tree browser, any account/login/sync chrome, an app icon. `DESIGN.md` §7 says why.

## Conventions

- One file per scenario. Inline CSS, no build step, no external requests, no JavaScript unless genuinely unavoidable.
- No image files. A mockup is self-contained: if a scenario genuinely cannot be shown without an image, inline it as a data URI. This folder has no `assets/` directory on purpose.
- States that share a layout (empty / loading / populated / error) go in the **same page** as labeled variants. Split files only when the layout itself differs.
- Annotate anywhere HTML cannot faithfully reproduce AppKit rather than silently drawing something slightly wrong.

## Never touch

- `index.html` — the hand-authored gallery.
- `README.md` — this file.

Both are maintained by hand. Do not edit, reformat, or improve them.
