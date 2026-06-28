# P4 semantic capture / blocks — explore-phase decisions (OSC 7 cwd + OSC 133)

> **Provenance:** Drafted 2026-06-28 during an `/opsx:explore p4` session, after **P3 completed** (P3a + P3b — `add-tabs-and-splits`, `add-quick-terminal`, `add-profiles` — all archived). Grounded in reads of the **SwiftTerm checkout** (`…/SourcePackages/checkouts/SwiftTerm/Sources/SwiftTerm`), xtty's own `XttyCore`/`App`, and the **emit side** of OSC 133/7 from shallow clones of **Ghostty** (`src/shell-integration`, `src/terminal`) and **Kitty** (`shell-integration`). Produced by a research workflow (4 parallel source-readers → 2 adversarial verifiers on the gating claims → synthesis); **both gating claims were independently confirmed.** No code written.

> _Topic scope:_ Lock the decisions for **P4, the keystone milestone** ([milestones P4](../04-design/02-milestones.md)). P4 is the first milestone that reads *meaning* from the byte stream (cwd + command boundaries) and feeds every downstream differentiator (P5 session sidebar, P6 file/diff view, the deferred P3b file:line error-matching). Background: [modern innovations](../02-internals/08-modern-innovations.md), [agents & xtty](agents-and-xtty.md), [requirements H3](xtty-requirements.md).

---

## The headline decision: ship **P4a only** (fork-free); defer **P4b** (spatial ops, needs a fork)

The OSC 133/7 **data model is the genuine keystone** — P5/P6 depend on the captured *command + exit + cwd + timestamps + state*, **not** on spatial operations — and it is **100% achievable on SwiftTerm's public API**. The spatial ops are blocked behind **two independent internal-API walls**, making them a separable, deliberately-reviewed change:

```
 P4a  OSC 7 cwd  +  OSC 133 lifecycle/data model  +  zsh injection  +  alt-screen gating
        └─► 100% PUBLIC API ✅      └─► unblocks P5 sidebar, P6 cwd, P3b file:line matching

 P4b  jump-to-prompt · select-a-command's-output · gutter fail-marks
        ├─ stable row anchor  → needs INTERNAL  buffer.yBase + buffer.linesTop
        └─ select-output      → needs INTERNAL  SelectionService / view.selection
        └─► requires a small SwiftTerm FORK + dependency repoint ✋ (separate change)
```

**Why split, not bundle:** select-output is fork-gated *regardless* of the coordinate question (the selection type is unreachable cross-module), so P4b is a one-way-ish architectural commitment (fork + repoint two manifests + rebase maintenance). Risk-coupling that with the high-value, downstream-unblocking data change is wrong; keeping P4a fork-free also keeps the keystone small enough to review/validate/archive cleanly per the milestone-per-change cadence.

---

## Q1 — Scope → **P4a alone** (✅ high confidence)

The synthesis of Q2–Q4 below. P4a delivers the keystone value with public API; P4b is carved out behind the fork. `proposeReady = true` for P4a.

| Capability | P4 phase | Gate |
|---|---|---|
| OSC 7 cwd (new-split cwd, file:line base) | **P4a** | public delegate (already stubbed) |
| OSC 133 A/B/C/D parse + block data model | **P4a** | public `registerOscHandler` |
| Shell-integration injection (zsh) | **P4a** | env-var only |
| Alt-screen block gating | **P4a** | public `isCurrentBufferAlternate` + `open bufferActivated` |
| jump-to-prompt · select-output · gutter marks | **P4b** | **SwiftTerm fork** (internal `yBase`/`linesTop` + `SelectionService`) |

---

## Q3 — The coordinate gap → **confirmed unsolvable via public API** (✅ verified)

The blocks model would like to anchor each command's output to **stable rows** (for jump/select/mark). It can't, from outside SwiftTerm's module:

- ❌ `buffer.linesTop` (the monotonic trim counter), `buffer.yBase`, and `buffer.lines` are **all `internal`** (no `public`) — `buffer` itself is only `public private(set)`. So neither the buffer-index cursor row (`y + yBase`) nor the scroll-invariant absolute row (`y + yBase + linesTop`) is computable cross-module. — *Buffer.swift:27 (`var linesTop`), :32 (`var yBase`), :201 (`var lines`); Terminal.swift:326 (`public private(set) var buffer`)*
- ❓ `getCursorLocation()` returns `(buffer.x, buffer.y)` where **`y` is *live-region-relative* (relative to `yBase`), not display-relative** — a *third* coordinate basis distinct from `getLine`/`getTopVisibleRow` (both `yDisp`-relative). SwiftTerm's own doc-comment mislabels it "relative to visible display." — *Terminal.swift:5079–5081, 5086–5088*
- ❌ The only public **absolute reader**, `getScrollInvariantLine(row:)` = `lines[row - linesTop]`, has **no public writer / absolute-cursor counterpart**, and `getScrollInvariantUpdateRange()` is in a *different* (buffer-index, `yDisp+y`) space — must not be mixed with it. — *Terminal.swift:743–748, 5053–5061*
- ❌ **No public delegate fires on a scrollback trim** (only `scrolled(yDisp:)` / `linefeed()`, neither absolute). A buffer-index anchor silently drifts down 1 per trimmed line once scrollback is full. — *Terminal.swift:81, 85; trim math 5252–5261 (`yBase++` when not trimmed vs `linesTop++` when trimmed)*
- ⚠️ `clear`/`reset` (ED 3 / CSI 3 J, emitted by modern `clear`) **resets `linesTop = 0`** with no callback — any stored absolute anchor rots. — *Terminal.swift:2369; Buffer.swift:284, 355*

**Decisions:**
- ✅ **P4a stores NO fragile coordinates.** Capture durable fields from the OSC byte stream (cmdline, exit code, cwd, timestamps, state) and grab output text **eagerly at `D`** via the public `getText(start:end:)` (public `Position`/`BufferLine`). — *Terminal.swift:5869*
- ❌ **Never persist** the bottom-anchored `buffer.y + getTopVisibleRow()` proxy as truth — it is correct only when scrolled to the bottom and rots on trim. (Usable at most as a best-effort hint for *visible/recent* blocks, explicitly flagged.)
- ✅ **Pre-commit to Option D for P4b: a ~5-line *upstreamable* SwiftTerm fork** exposing a public absolute-cursor-row / `linesTop` accessor (symmetric with the already-public `getScrollInvariantLine`). Rejected alternatives: **Option C** reflection/probing (brittle on private field names, breaks on the `linesTop=0` reset), **Option B** re-anchor-on-trim (dead end — no public trim signal).

---

## Q4 — Alt-screen detection + block lifecycle → **clean public path, no fork** (✅ verified)

Better than feared. Unlike `linesTop`, the alt-screen hooks are genuinely public/`open` (the verifier contrasted them explicitly):

- ✅ **Truth source (public property):** `public var isCurrentBufferAlternate: Bool { buffer === altBuffer }`. (Read this inside the callback; also the polling fallback. Note `altBuffer`/`displayBuffer` are internal — use the accessor, not `buffer === altBuffer` directly.) — *Terminal.swift:342–344*
- ✅ **Push hook (overridable):** `bufferActivated(source:)` is a **`TerminalDelegate` protocol requirement** with an `open` view implementation; xtty's `XttyTerminalView : LocalProcessTerminalView : TerminalView` can `override` it (iOS ships the identical override as precedent). Because it's a protocol *requirement* satisfied by an `open` method, the engine's internal `tdel` still dispatches to the subclass (not the static-dispatch protocol-extension gotcha). Fires only on real 47/1047/1049 switches; mode 1048 (cursor save/restore) does **not** fire it. — *Terminal.swift:18, 89, 6635/6657; Mac/MacTerminalView.swift:554; iOS/iOSTerminalView.swift:1277; activate sites 4355/4359, 4116/4123*
- ⚠️ Residual risk: the push hook depends on SwiftTerm keeping the method `open` (it does today; SwiftTerm's own subclassing depends on it). Fallback: poll `isCurrentBufferAlternate`. Add a harness test that drives an alt-screen app and asserts the override fired.

**Lifecycle rules** — a **view-free state machine in `XttyCore`** `{idle, atPrompt, runningCommand}` (mirrors the zsh emit-side + Ghostty's structural choices):
1. ✅ Open a block **only on `C`**, close **only on `D`**, recording `D`'s exit code.
2. ✅ On `A` (or `P` with `k≠s`) with no intervening `C`, **discard the prompt-only region** (empty-Enter / Ctrl-C-on-unrun-line → no block).
3. ✅ `D` with no open `C` is a **defensive no-op**; count **only the first `D` after a `C`** (kitty emits multiple).
4. ✅ Treat `k=s` / `P` continuation marks as part of the same command (don't start a new block on PS2 lines).
5. ✅ **Gate on alt-screen:** while `isCurrentBufferAlternate` suppress block create/close (vim/htop/less never become blocks); if alt is entered mid-command, mark the command full-screen/opaque and finalize on the `D` after returning to primary.
6. ✅ **OSC 133 is best-effort:** absent marks (tmux / ssh without remote integration) degrade to plain output with no blocks — **never gate core rendering on them.**

---

## Q2 — Shell-integration injection → **auto-inject via `ZDOTDIR` from v1** (✅ high confidence)

OSC 133/7 are emitted *by the shell*, so xtty must get the shell to run our hooks. Ghostty and Kitty both auto-inject; the **zsh `ZDOTDIR` redirection** is the cleanest fit for xtty (whose user runs zsh):

- ✅ **Mechanism:** set `ZDOTDIR=<bundle>/shell-integration/zsh` in the child env. zsh always sources `$ZDOTDIR/.zshenv` first; our bootstrap `.zshenv` (1) **restores** the user's original `ZDOTDIR` (or unsets it), (2) sources the user's real `.zshenv`, then (3) in an `always` block, if interactive, autoloads + runs the hook-installer and `unfunction`s it. Because `ZDOTDIR` is restored at `.zshenv` time, the user's `.zprofile`/`.zshrc`/`.zlogin` **still load from their real dir** — only `.zshenv` is intercepted. — *ghostty zsh/.zshenv:28–33 (restore), :45–48 (source user), :49–60 (autoload+run); kitty zsh/.zshenv:16–45*
- ✅ **Hooks:** `add-zsh-hook precmd/preexec` emitting OSC 133 `A`/`B`/`C`/`D` + OSC 7; coexists with p10k/starship via the **additive** hook arrays.
- ✅ **Compatible with our launch model:** env-var-only → no change to the forkpty/`execve`/no-PATH path or the existing `-zsh` login `execName`. The smallest possible diff.
- ❌ **Manual-snippet-first rejected:** the signature OSC-133 sidebar would silently do nothing until users edit dotfiles (most never do). Ship a documented manual fallback (`source <bundle>/…/ghostty-integration`-style installer) for the `/etc/zshenv`-override / opt-out edge cases.
- ⚠️ **Confirmed gotcha in our code:** `ShellResolver.seedEnvironment` replaces the child env wholesale and **drops a pre-existing `ZDOTDIR`**. Must read `environment["ZDOTDIR"]` **before** seeding and forward it as `XTTY_ORIG_ZDOTDIR`. — *ShellResolver.swift:85–97, 135–136; PaneController.swift:86*
- ✅ **Keep the seam pure:** thread the bundle path into `ShellResolver` as an **injected parameter** (unit-testable, like the existing `home`/`exists` injections). **Skip injection for profile `command` one-shots.** Defer bash/fish auto-inject (bash needs POSIX-mode + `ENV` + `bash-preexec`; macOS `/bin/bash` 3.2 can't auto-inject at all — fish uses `XDG_DATA_DIRS` + `vendor_conf.d`).

---

## Protocol grammar (nailed from emit-side ground truth — for the proposal)

### OSC 133
- ✅ **Register** `engine.registerOscHandler(code: 133, …)` — SwiftTerm has **no built-in 133** (falls to a log-only fallback); user handlers are checked **first**. The handler receives bytes **after the first `;`** (e.g. for `133;D;1;aid=foo` → `D;1;aid=foo`). — *EscapeSequenceParser.swift:510–544, 833–840; Terminal.swift:1054–1057*
- ✅ **Grammar:** `ESC ] 133 ; <ACTION> [ ; key=value … ] ST` (ST = BEL `0x07` or `ESC \`). Parse: `action = byte[0]`; if `byte[1]==';'` split the remainder on `;`, splitting each token on the **first** `=`.
- ✅ **Actions:** `A` (fresh-line + prompt start), `B` (prompt end / input start), `C` (input end / **output start**), `D` (command end). Also accept `P` (prompt-start, no fresh-line — used inside PS1); **ignore unknown action bytes** (e.g. kitty `133;k;…`). — *ghostty semantic_prompt.zig:22–31, 330–385*
- ✅ **`D`'s exit code is a BARE positional integer** (first token after `D;`), parsed as `i32` (can be negative); bare `133;D` = no code; `133;D;12;aid=foo` puts `aid` *after* the code. **Not** a `key=value`. — *semantic_prompt.zig:164–172; emit: ghostty zsh:116/120, fish:141/155, bash:177; kitty bash:258*
- ✅ **`cmdline=` / `cmdline_url=` (on `C`)** carry the command text — `cmdline` is shell-quoted (`%q`), `cmdline_url` is percent-encoded; decode with **raw fallback**. — *kitty bash:227; ghostty fish:106; semantic_prompt.zig:50–60*
- ✅ **`k=s`** marks secondary/continuation prompts (PS2) — don't start a block. `aid=` (shell instance id) is **optional/best-effort** (ghostty bash emits it; zsh/fish/kitty basic prompts don't). — *kitty bash:156/259; ghostty zsh:158*
- ✅ **v1 useful subset:** `A`/`B`/`C`/`D` + exit code + `cmdline`/`cmdline_url` + `k=s`. Ignore `cl`/`redraw`/`click_events`/`special_key` (click/resize cosmetics). **Defer OSC 633 (VSCode)** — Ghostty/Kitty implement only 133; FinalTerm 133 A/B/C/D is the safe interoperable core.

### OSC 7
- ✅ **Fill the existing no-op delegate** (`PaneController.swift:127`) — do **NOT** register a custom OSC 7 handler. SwiftTerm's built-in handler stores the cwd and fires `hostCurrentDirectoryUpdate(directory:)`, gated on `isProcessTrusted` (already `true` on macOS); a custom handler would bypass that and stop populating `hostCurrentDirectory`. — *Terminal.swift:1663–1675; Mac/MacTerminalView.swift:2293–2295; AppleTerminalView.swift:300*
- ✅ **SwiftTerm hands us the RAW undecoded URL** → xtty decodes: strip scheme (`file://` **or** kitty's `kitty-shell-cwd://`), take authority up to the first `/` as **host**, the rest as **path**; **percent-decode the path ONLY for `file://`** (leave `kitty-shell-cwd://` raw); compare host to the local hostname to **flag remote/ssh cwd** (don't treat it as a local filesystem path); skip `~`-expansion (PWD is absolute). — *emit: ghostty bash:196/zsh:235 + kitty bash:207/fish:135 use `kitty-shell-cwd://`; ghostty fish:164 uses `file://`*

---

## Recommended P4a task spine

1. **OSC 7 cwd** — fill the `hostCurrentDirectoryUpdate` stub (`PaneController.swift:127`); tolerant decoder (above); store per-pane cwd in the `XttyCore` session model (and use it for new-split cwd — the milestone "done when").
2. **zsh injection** — ship the bundled `shell-integration/zsh` dir; thread bundle path into `ShellResolver` as an injected param; set `ZDOTDIR` + forward pre-existing one as `XTTY_ORIG_ZDOTDIR` (read **before** the wholesale seed); skip for `command` one-shots.
3. **OSC 133 parser** — view-free, pure, in `XttyCore` (grammar above); registered via `engine.registerOscHandler(code: 133)`.
4. **Alt-screen detection** — override `open func bufferActivated` in `XttyTerminalView` (`super` first, then read `isCurrentBufferAlternate`); polling fallback.
5. **Block lifecycle machine** — view-free `XttyCore` state machine wiring parser + alt-gating + eager output-text capture; a `BlockRegistry` per `TerminalSession`.
6. **Harness** — new DEBUG state dump (alt-state + last OSC-133 transition + block list — the custom-drawn view exposes nothing to accessibility); e2e driving **real zsh-with-injection** asserting blocks form, exit codes captured, and `vim`/`tput smcup` suppresses blocks.

---

## Cross-cutting risks (carry into the proposal)

- ⚠️ **Concurrency (Swift 6):** OSC 133 handlers + `bufferActivated` run on the engine feed path; the existing delegate methods are `nonisolated` (with `MainActor.assumeIsolated` hops). Reading `buffer.x/y/yDisp` and mutating the block model must be confined to the engine's thread/actor — **confirm the OSC handler execution context** in `PaneController`/`TerminalSession` before relying on snapshots.
- ⚠️ **`linesTop=0` on clear/reset** has no callback — the data model must at least not present stale anchors (more acute for P4b).
- ⚠️ **Degradation under tmux/ssh:** no DCS-passthrough unwrap in SwiftTerm; marks may never arrive — document "no blocks, plain output" as accepted; never block-gate rendering.
- ⚠️ **DEBUG-only observability:** rules + alt-gating are untestable in XCUITest without the new state dump — build it *as part of P4a* or the rules ship unverified.
- ⚠️ **OSC 7 trust flag:** if xtty ever flips `isProcessTrusted` false, the built-in OSC 7 path silently stops firing — keep cwd on the delegate, never a custom handler, and re-test if the trust setting changes.
- ❓ **Empirical edge cases (validate, not proposal blockers):** whether `D` can fire while the user is scrolling; p10k instant-prompt early-output warnings; fish's lack of `k=s` continuation marks (may need Ghostty's col-0 heuristic).

---

## The deferred P4b (separate change, after a fork)

`add-…-spatial-blocks` (name TBD), gated on a SwiftTerm fork:
1. Land the **read-only coordinate accessor fork** (public absolute-cursor-row / `linesTop`), then SelectionService exposure for select-output.
2. **jump-to-prompt** (scroll to a block's anchor via `view.scrollTo`, anchor = `absolute - linesTop`), **select-a-command's-output**, **gutter fail-marks**, with **anchor invalidation on the `linesTop=0` clear/reset**.
3. Repoint the dependency in `XttyCore/Package.swift` + the App package ref; pin + rebase-maintain the fork; pursue upstreaming the accessors.

This also subsumes the **P3b-deferred file:line error-matching** for *clicking* a match (the cwd half lands in P4a; the click-to-open + gutter affordance can ride P4b or P5).

---

## Sources

- **SwiftTerm checkout** — `…/SourcePackages/checkouts/SwiftTerm/Sources/SwiftTerm`: `Terminal.swift`, `Buffer.swift`, `EscapeSequenceParser.swift`, `Apple/AppleTerminalView.swift`, `Mac/MacTerminalView.swift`, `Mac/MacLocalTerminalView.swift`, `iOS/iOSTerminalView.swift`, `SelectionService.swift`, `Apple/TerminalViewDelegate.swift` (line cites inline above).
- **Ghostty** (shallow clone `ghostty-org/ghostty`, 2026-06-28) — `src/shell-integration/{zsh,bash,fish,README.md}`, `src/terminal/osc/parsers/semantic_prompt.zig`, `src/terminal/report_pwd.zig`.
- **Kitty** (shallow clone `kovidgoyal/kitty`, 2026-06-28) — `shell-integration/{zsh,bash,fish}`.
- **xtty** — `App/PaneController.swift`, `App/XttyTerminalView.swift`, `App/XttyApp.swift`, `XttyCore/Sources/XttyCore/{ShellResolver,TerminalSession,Pane,XttyConfigLoader}.swift`.
- **Method** — research workflow `p4-open-questions-research` (4 source-readers → 2 adversarial verifiers on the coordinate-gap + alt-screen gating claims → synthesis); both gating claims **confirmed**. See also [P3b shell-UX decisions](p3b-shell-ux-decisions.md) (the `execve`/login-shell launch reality this builds on) and [agents & xtty](agents-and-xtty.md) (OSC 133 as the differentiator foundation).
