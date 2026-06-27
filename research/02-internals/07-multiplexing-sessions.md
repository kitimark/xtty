# Multiplexing & Session Features

> **Provenance:** Generated 2026-06-27 from a 39-agent research workflow (10-terminal survey + adversarial fact-check + 8 architecture deep-dives + synthesis), 281 web lookups. Claims marked surprising/marketing-flavored were independently fact-checked (see [fact-checks](../03-analysis/fact-checks.md)).

> _Topic scope:_ Terminal multiplexing and session features: tmux vs built-in splits/tabs/panes, scrollback, reflow on resize, search, and persistent sessions (macOS focus)

## Summary

A terminal "multiplexer" like tmux runs as a background server that owns the shell processes; the visible terminal is just a thin client that can detach and reattach, so work survives closed windows and dropped SSH connections. A terminal emulator's own tabs/splits are simpler and feel more native, but the panes die when the app or connection dies because the emulator itself owns the PTYs. The other big session features — scrollback (saved history above the screen), reflow (re-wrapping lines when the window resizes), and search — all operate on a grid-of-cells model of the screen plus a history buffer, and each has subtle, well-known hard parts. On macOS, iTerm2 famously bridges both worlds via tmux "control mode" (tmux -CC), driving native iTerm2 tabs/panes from a real tmux server.

## Key points

- Two layers do similar-looking things differently: a terminal EMULATOR (iTerm2, Terminal.app, kitty, WezTerm, Ghostty, Alacritty) draws cells and owns the pseudo-terminal (PTY) for each pane; a MULTIPLEXER (tmux, GNU screen, Zellij) is a separate process that owns the PTYs and just streams a rendered view to whatever client is attached. Built-in splits/tabs live entirely inside the emulator process; tmux splits live in the tmux server.
- tmux uses a client/server architecture: a long-lived server process holds sessions/windows/panes and the child shells; one or more clients attach over a unix socket. This is what enables detach/reattach, multiple simultaneous clients on one session (pair programming), and survival across SSH drops. GNU screen does similar but tmux's design is cleaner and supports multi-attach better.
- Persistent sessions are the headline reason to use tmux over native splits: detach (prefix+d), close the terminal or lose the network, and processes keep running; reattach later from the same or a different machine with `tmux attach`. Native emulator panes cannot do this — killing the window or losing the SSH link kills the shells, because the emulator that owned the PTYs is gone.
- Scrollback buffer = lines that scrolled off the top of the visible grid are pushed into a history ring buffer. It is normally bounded (WezTerm defaults to 3500 lines via scrollback_lines; the value is an upper bound and bigger means more memory). tmux keeps its own per-pane history (history-limit). The emulator's scrollback and tmux's scrollback are separate; inside tmux you scroll tmux's buffer (copy-mode), not the emulator's.
- A common mental model (WezTerm's): the visible viewport is a fully MUTABLE grid of cells that escape sequences freely move the cursor around and overwrite; once lines scroll off the top they become (largely) IMMUTABLE scrollback. Knowing when it is 'safe' to push a line into scrollback is itself nontrivial because programs can move the cursor after any byte, so parsing can never assume input is line-based.
- Reflow on resize means re-wrapping soft-wrapped lines to the new column count when the window width changes. It is optional and hard: terminals must track which line breaks are 'soft' (auto-wrap) vs 'hard' (an actual newline) to rewrap correctly, must recompute cursor position, and must avoid corrupting immutable scrollback. Many bugs come from resize/SIGWINCH handlers emitting extra redraws that duplicate content into the live region.
- Search over scrollback runs a string/regex match across the cell grid plus history, then scrolls the viewport to and highlights matches. iTerm2 has rich regex search and 'triggers' (regexes that fire actions like highlight/alert on matching output) across the whole scrollback; kitty historically lacked in-app scrollback search and added it later; matching across soft-wrapped line boundaries is a notable complication.
- On macOS specifically: iTerm2's tmux control mode (`tmux -CC attach`) is the standout integration — tmux sends a structured text protocol (designed by iTerm2's author George Nachman) instead of a rendered TUI, so tmux windows/panes map onto NATIVE iTerm2 tabs and split panes while keeping tmux persistence and remote survival. You get native scrollback, search, and mouse with real tmux sessions underneath.
- Decision guide: for a single local machine with short-lived tasks and heavy GUI use, native emulator splits are simpler and faster. Choose tmux when you need persistence, remote/SSH survival, multi-client sharing, or a consistent split UI across many servers that have no GUI terminal. They also compose: run native tabs locally and tmux on the remote host.
- tmux sizing gotcha for multi-client: when two clients attach to the same session, tmux constrains the window to the SMALLEST attached client's dimensions (unless using window-size/aggressive-resize options), which can leave unused margins. Native emulator panes don't have this because there is only ever one viewer per pane.

## How real terminals do it

- tmux/GNU screen/Zellij: classic detached multiplexers. tmux server owns sessions>windows>panes; clients attach via unix socket; `tmux attach` reconnects after SSH drops. Zellij (Rust) is a modern alternative with built-in layouts and a discoverable UI.
- iTerm2 (macOS): native tabs + split panes drawn by the app, PLUS tmux control mode (tmux -CC) that maps a real tmux server's windows/panes onto native iTerm2 UI. Also has regex scrollback search and configurable 'triggers' that run actions on matching output.
- WezTerm: documents the mutable-viewport / immutable-scrollback model explicitly; configurable scrollback_lines (default 3500) as an upper bound; CTRL-SHIFT-F search scrolls viewport to matches; treats the viewport as a fully mutable grid of cells that escape sequences mutate byte-by-byte.
- kitty: high-performance GPU terminal; historically had no in-app scrollback search (users migrating from iTerm2 requested it on GitHub) and pipes scrollback to a pager/editor; later gained search — illustrates that scrollback search is a real feature to design, not a freebie.
- Apple Terminal.app (macOS built-in): native tabs and window splits, scrollback with find, but no detached/persistent sessions and weaker reflow — a baseline for what 'built-in only' gives you.
- Ghostty / Alacritty: modern GPU emulators that deliberately keep multiplexing OUT of scope, expecting users to pair them with tmux/Zellij — a valid architectural choice (do one thing well) for someone building a new terminal.
- OpenAI Codex / Claude Code TUIs: real-world bug reports (codex PR #18575 'reflow scrollback on terminal resize', claude-code issue #49086 content duplication on resize) show that even modern apps get reflow/redraw-on-resize wrong — concrete evidence of the hard parts.

## Pitfalls / hard parts

- Reflow correctness: you must distinguish soft wraps (auto-wrap at right margin) from hard newlines, or rewrapping produces garbled paragraphs. Storing a per-line 'wrapped' flag is the usual fix; getting it right for double-width/CJK and zero-width characters is harder.
- Resize duplicating content: SIGWINCH/PTY-resize handlers that trigger extra redraws, or reflow paths that re-walk the page buffer and APPEND already-rendered rows instead of rewrapping in place, cause the classic 'banner repeated many times in scrollback' artifact (see codex/claude-code/cmux issues).
- Cursor position after reflow: re-wrapping changes how many rows existing text occupies, so the cursor can land in the wrong place — or worse, in the now-immutable scrollback, which later prompt redraws then corrupt.
- Knowing when a line is 'done' and safe to commit to scrollback: applications can move the cursor anywhere after any byte (full-screen TUIs, progress bars), so you cannot assume line-based input; committing too eagerly breaks redraws, too late wastes memory.
- Two scrollbacks problem: when running tmux inside an emulator, the emulator's native scroll/search operates on tmux's last rendered frame, not tmux's real history; users get confused that mouse-scroll shows junk unless tmux's own copy-mode and mouse settings are configured.
- Scrollback memory and reflow cost: an unbounded or very large buffer eats memory, and reflowing the ENTIRE history on every resize is O(history) — wide histories may need lazy/on-demand rewrapping; tmux historically didn't reflow old scrollback at all, leaving stale wrapping until new output replaces it.
- Multi-client sizing: with several attached tmux clients the session is clamped to the smallest viewport, producing dead margins; you need window-size/aggressive-resize policies and a strategy for what 'the' size even means.
- Search across wrapped lines and styled cells: a match can straddle a soft-wrap boundary or include cells with color/attribute runs; naive per-row string search misses these, and regex over a 2D cell grid needs a flattened logical-line view.
- Control-mode/protocol integration (iTerm2 -CC) is powerful but couples you to tmux's protocol quirks and version differences; it is a substantial implementation surface, not a quick win.
- Persistence boundaries: native panes can never survive app/SSH death because the emulator owns the PTYs — if you want persistence in your own terminal you must either embed a server like tmux's design or integrate with tmux, not bolt it on later.

## macOS specifics

iTerm2 is the macOS reference point: it offers native tabs/splits AND deep tmux integration via control mode (tmux -CC attach), a structured text protocol authored by iTerm2's creator George Nachman that maps tmux windows/panes onto native iTerm2 tabs and panes while keeping real tmux persistence and SSH-survival. This is the cleanest way on macOS to get native scrollback, search, mouse, and GPU rendering on top of genuine detached tmux sessions. Apple's built-in Terminal.app has native tabs/splits, scrollback, and find but no persistent/detached sessions. Newer macOS GPU terminals (kitty, WezTerm, Alacritty, Ghostty) vary: WezTerm has its own multiplexer and explicit scrollback model; Alacritty and Ghostty intentionally omit multiplexing and expect tmux/Zellij. macOS apps also wire these features to standard Cmd-key UI (Cmd-T tab, Cmd-D split, Cmd-F find) rather than tmux's prefix keybindings.

## Sources

- https://opensource.com/article/20/7/tmux-cheat-sheet
- https://www.lullabot.com/articles/multiple-terminal-panes-tmux
- https://petronellatech.com/blog/zellij-terminal-multiplexer-guide-2026/
- https://github.com/tmux/tmux/wiki/Control-Mode
- https://iterm2.com/documentation-tmux-integration.html
- https://deepwiki.com/gnachman/iTerm2/5.2-tmux-integration
- https://evoleinik.com/posts/iterm2-tmux-control-mode/
- https://wezterm.org/scrollback.html
- https://github.com/wezterm/wezterm/discussions/3356
- https://github.com/openai/codex/pull/18575
- https://github.com/anthropics/claude-code/issues/49086
- https://github.com/manaflow-ai/cmux/issues/3052
- https://iterm2.com/documentation-search-syntax.html
- https://github.com/kovidgoyal/kitty/issues/893
- https://github.com/kovidgoyal/kitty/issues/718
- https://medium.com/free-code-camp/tmux-in-practice-scrollback-buffer-47d5ffa71c93
- https://dedirock.com/blog/increasing-the-scrollback-buffer-size-in-linux-terminal-emulators-a-step-by-step-guide/
