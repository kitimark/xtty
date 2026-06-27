# VT/ANSI Escape-Sequence Parsing

> **Provenance:** Generated 2026-06-27 from a 39-agent research workflow (10-terminal survey + adversarial fact-check + 8 architecture deep-dives + synthesis), 281 web lookups. Claims marked surprising/marketing-flavored were independently fact-checked (see [fact-checks](../03-analysis/fact-checks.md)).

> _Topic scope:_ VT/ANSI escape-sequence parsing and the DEC-inspired parser state machine (terminal-emulator architecture, macOS focus)

## Summary

A terminal emulator receives a flat byte stream from the program (the "child" running on the PTY). Most of those bytes are text to print, but interleaved are escape sequences that mean "move the cursor," "set color red," "set the window title," etc. The job of the parser is to walk that byte stream one byte at a time and split it into "print this character" vs. "this is a command" without ever getting stuck, even on garbage input. The de-facto standard way to do this is Paul Williams' state machine (published at vt100.net), reverse-engineered from real DEC VT200/VT500 hardware: a small, total finite-state machine where every byte in every state has a defined transition and action. You almost never write this from scratch — you reuse a battle-tested library (alacritty's vte in Rust, vtparse, libvte/GLib's VTE widget, Ghostty's libghostty-vt) which gives you parse events and leaves the *meaning* of the sequences to you.

## Key points

- Two layers: (1) a syntactic parser that classifies bytes into events (print, execute, csi_dispatch, esc_dispatch, osc_dispatch, hook/put/unhook for DCS), and (2) a semantic layer (the 'terminal') that actually mutates the screen grid, cursor, scroll region, modes, colors. The Williams state machine is only layer 1; it deliberately ascribes no meaning to sequences.
- Sequence families you must distinguish: C0 controls (0x00-0x1F, single bytes like BS, HT, LF, CR, BEL — executed immediately); C1 controls (0x80-0x9F, the 8-bit forms); ESC sequences (ESC + intermediates + final, no parameters, e.g. ESC = , ESC c hard reset); CSI sequences (ESC [ or 0x9B, with numeric params separated by ';', optional private marker like '?', optional intermediates, then a final byte — e.g. CSI 2 J erase screen, CSI 1;31 m SGR bold red); OSC strings (ESC ] or 0x9D, e.g. OSC 0;title ST set window title, OSC 8 hyperlinks, OSC 52 clipboard); DCS strings (ESC P or 0x90, e.g. Sixel graphics, DECRQSS); and SOS/PM/APC strings (usually ignored to terminator).
- Williams parser has ~14 states: ground, escape, escape_intermediate, csi_entry, csi_param, csi_intermediate, csi_ignore, dcs_entry, dcs_param, dcs_intermediate, dcs_passthrough, dcs_ignore, osc_string, sos/pm/apc_string. Source: https://vt100.net/emu/dec_ansi_parser .
- Actions attached to transitions: print, execute, clear (reset collected state on entry), collect (gather intermediates/private markers), param (build the numeric parameter list from 0x30-0x39 and ';'), esc_dispatch, csi_dispatch, hook/put/unhook (DCS data passthrough), osc_start/osc_put/osc_end. The library calls back into your code at the *_dispatch and put points.
- Two properties make the machine robust: completeness (every byte in every state has a defined action+transition, so the parser can never hang or panic on malformed input) and the 'anywhere' transitions (CAN 0x18 and SUB 0x1A abort any in-progress sequence and return to ground; ESC restarts a sequence from anywhere; the 8-bit C1 introducers 0x90/0x9B/0x9D etc. jump straight into the matching state). This is what lets a terminal recover gracefully from a partially-written or corrupt sequence.
- Compatibility ladder: VT100 (the baseline, 7-bit, defined most cursor/erase/SGR sequences) -> VT220 (8-bit C1 controls, more modes) -> VT320/VT420/VT520 -> xterm (the modern superset everyone targets: 256/truecolor SGR, mouse reporting, bracketed paste, focus events, OSC title/clipboard/hyperlinks, DECSET private modes). 'xterm-256color' is the usual TERM value and xterm's ctlseqs document is the practical reference.
- Library landscape: alacritty/vte (Rust) exposes a Perform trait with print/execute/hook/put/unhook/osc_dispatch/csi_dispatch/esc_dispatch callbacks; vtparse (Rust, from wezterm's author) is a similar DEC-parser port extended for UTF-8; libvte (GNOME's GLib/GTK widget, the C library behind GNOME Terminal — a *full* widget, not just a parser); go-vte ports alacritty's vte to Go; Ghostty's libghostty-vt is a zero-dependency C library with a SIMD-optimized parser extracted from Ghostty.
- UTF-8 is layered *outside or alongside* the escape parser: printable text is decoded as UTF-8 into Unicode scalar values before/while being fed to print, while the control-byte ranges (< 0x20, and the C1 range handling) are intercepted by the state machine. Modern parsers integrate a UTF-8 decoder so multibyte characters reach print() as full codepoints; the original DEC machine predates UTF-8 and treated GR bytes 0xA0-0xFF like GL printables.

## How real terminals do it

- Alacritty: uses its own vte crate. You implement the Perform trait (print, execute, csi_dispatch, osc_dispatch, esc_dispatch, hook/put/unhook) and the state machine drives your callbacks. docs.rs/vte trait.Perform.
- WezTerm: uses vtparse (Joshua Haberman's DEC-parser design ported to Rust and extended for UTF-8) underneath its termwiz crate; vtparse categorizes sequences without assigning semantics (CollectingVTActor collects events).
- GNOME Terminal / many GTK apps: embed libvte (the VTE widget), a full C terminal component, not just a parser — it includes the parser plus screen model plus rendering.
- Ghostty (macOS-native, GPU-accelerated): hand-written state machine following Williams, now being shipped as libghostty-vt, a zero-dependency C library with SIMD-optimized byte scanning, fuzzed and Valgrind-tested, and support for the Kitty graphics protocol, synchronized output, and clipboard/OSC sequences.
- xterm: the canonical reference implementation; its ctlseqs document (invisible-island.net/xterm/ctlseqs) is the spec people actually code against for the 'xterm-compatible' superset.
- kitty and iTerm2 (both popular on macOS): implement the same parser core but add their own protocol extensions (kitty graphics/keyboard protocols; iTerm2's proprietary OSC 1337 sequences for inline images, badges, etc.).
- JediTerm (JetBrains IDEs) is the cautionary example: it mishandles CSI intermediates, so the cursor-shape sequence (CSI Ps SP q, where SP 0x20 is an intermediate) swallows a character — cited by Ghostty's author as proof the 'simple' diagram is hard to implement correctly.
- Linux kernel virtual console implements a close cousin of this machine (documented in console_codes(4)).

## Pitfalls / hard parts

- OSC terminator ambiguity: ECMA-48 says OSC ends with ST (0x9C, or the 7-bit ESC \), but xterm historically also accepts BEL (0x07). You must accept both, and ideally echo back the same terminator the client used. Forgetting BEL termination makes you swallow all following output as part of the title/clipboard string.
- C1 controls vs UTF-8 collision: in 8-bit/Latin-1 mode 0x80-0x9F are the C1 introducers (0x9B = CSI, 0x9D = OSC, etc.), but in UTF-8 mode those same bytes are valid continuation bytes of multibyte characters. Most modern terminals deliberately disable raw 8-bit C1 handling in UTF-8 mode (only honoring the 7-bit ESC-prefixed forms) to avoid corrupting text. Getting the interleaving of UTF-8 decoding and control-byte interception right is genuinely subtle.
- Intermediate bytes are easy to get wrong: the 0x20-0x2F range between params and the final byte (e.g. the space in CSI Ps SP q 'set cursor shape', or '!' in CSI ! p soft reset). Naive parsers treat the final byte as immediately following params and either drop the intermediate or eat the next character — the JediTerm bug.
- Parameter parsing edge cases: empty/default parameters (CSI ;5 H vs CSI H), the sub-parameter colon separator 0x3A used by SGR truecolor (CSI 38:2::r:g:b m) which the original DEC machine ignores, parameter overflow (cap counts — DEC processed only ~16 params and clamped values to ~9999), and private-marker prefixes (?, >, =, <) that must appear only at the start of params (csi_ignore otherwise).
- DCS passthrough is a different beast: DCS strings (Sixel, DECRQSS, kitty graphics, terminfo queries) can be huge binary blobs. The parser must route data bytes verbatim via put() to a sub-handler and not try to interpret them; mis-detecting the ST terminator inside binary data corrupts the screen.
- Recovery / totality: real programs emit truncated or malformed sequences (e.g. a process killed mid-write). The parser must never hang or buffer unbounded; the Williams machine's csi_ignore/dcs_ignore states and the CAN/SUB/ESC anywhere transitions exist precisely to bound this. A from-scratch parser that lacks an ignore state can deadlock or desync.
- Streaming across reads: bytes arrive in arbitrary chunks from the PTY, so a single escape sequence can be split across two read() calls. The parser must be a resumable state machine that retains its state between feed() calls — you cannot assume a sequence is complete within one buffer.
- Mixing parsing and semantics: it's tempting to act on the screen inside the parser, but the proven design keeps the syntactic state machine independent (no semantics) and emits events to a separate terminal model. Coupling them makes the parser untestable and the bugs hard to isolate.

## macOS specifics

On macOS the parser logic itself is platform-independent — the macOS-specific parts are everything *around* it. You get the byte stream by opening a pseudo-terminal: forkpty()/openpty() (from <util.h>, link against System, no -lutil needed as on Linux) or posix_openpt()/grantpt()/unlockpt()/ptsname(), then read() the master fd and feed those bytes to the parser. macOS terminals worth studying are native ones: Ghostty (Zig/Swift, native AppKit + Metal, its libghostty-vt parser is the most modern open reference), iTerm2 (Objective-C, its own parser plus proprietary OSC 1337 sequences for inline images/badges), and Apple's Terminal.app (closed source, identifies as TERM=xterm-256color and is the conservative baseline you should at least match). If you build in Rust you'd typically pull in alacritty's vte crate; in C/Zig you can vendor libghostty-vt or port vtparse; GLib's libvte is Linux/GTK-centric and not a natural fit for a native Cocoa/Metal app. Render with Core Text/CoreGraphics or Metal; the parser feeds a grid model that your renderer draws.

## Sources

- https://vt100.net/emu/dec_ansi_parser
- https://vt100.net/docs/vt100-ug/chapter3.html
- https://en.wikipedia.org/wiki/ANSI_escape_code
- https://invisible-island.net/xterm/ctlseqs/ctlseqs.html
- https://docs.rs/vte/latest/vte/trait.Perform.html
- https://github.com/alacritty/vte
- https://docs.rs/vtparse/latest/vtparse/
- https://crates.io/crates/vtparse
- https://github.com/haberman/vtparse
- https://github.com/danielgatis/go-vte
- https://mitchellh.com/writing/libghostty-is-coming
- https://github.com/ghostty-org/ghostty/discussions/11348
- https://ghostty.org/docs/vt/concepts/sequences
- https://wezterm.org/escape-sequences.html
- https://gist.github.com/egmontkob/eb114294efbcd5adb1944c9f3cb5feda
- https://man7.org/linux/man-pages/man4/console_codes.4.html
- https://terminfo.dev/fundamentals/control-characters
- https://www.ethanheilman.com/x/28/index.html
