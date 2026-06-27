# PTY Fundamentals — the byte shuffler

> **Provenance:** Generated 2026-06-27 from a 39-agent research workflow (10-terminal survey + adversarial fact-check + 8 architecture deep-dives + synthesis), 281 web lookups. Claims marked surprising/marketing-flavored were independently fact-checked (see [fact-checks](../03-analysis/fact-checks.md)).

> _Topic scope:_ Terminal emulator fundamentals: the PTY master/slave pair, shell connection, controlling terminal, and the read/write byte loop (macOS/Unix)

## Summary

A terminal emulator is a GUI app that pretends to be the old hardware video terminal a Unix program expects to talk to. It does this with a pseudoterminal (PTY): a kernel-provided pair of connected endpoints — a master (PTM) the emulator holds, and a slave (PTS) the shell uses as its stdin/stdout/stderr. The kernel sits between them adding real terminal behavior (line editing, echo, signal generation like Ctrl-C). The emulator's whole job reduces to a byte-shuffling loop: keystrokes/GUI events get encoded to bytes and written to the master; bytes read back from the master are parsed for ANSI/VT escape sequences and painted onto an in-memory screen grid that the GUI renders.

## Key points

- A PTY is two linked endpoints. The MASTER (a.k.a. PTM, the '/dev/ptmx' end) is held by the terminal emulator. The SLAVE (PTS, e.g. /dev/ttys003) looks and acts like a real serial terminal device and is what the shell opens. Whatever you write to one end comes out the other; the kernel's tty line discipline sits in between.
- Modern setup uses the Unix98 path: posix_openpt(O_RDWR | O_NOCTTY) to get the master fd, then grantpt() to fix slave device permissions, unlockpt() to allow opening it, and ptsname() (or ptsname_r) to get the slave's path like /dev/ttysNNN. macOS (BSD-based) supports Unix98 PTYs; older BSD-style /dev/pty?? pairs are legacy and should not be used.
- forkpty() (in libutil) is the convenience function that wraps openpty()+fork()+login_tty() — it forks, makes the child's slave the controlling terminal, and dup2's it onto fds 0/1/2. Many terminals call it instead of doing the steps by hand. The parent keeps the master fd.
- The controlling-terminal dance in the child: close the master, call setsid() to start a new session (becoming session leader with no controlling tty), then ioctl(slave, TIOCSCTTY, 0) to make the slave the controlling terminal. This is what makes Ctrl-C / Ctrl-Z / Ctrl-\ generate SIGINT/SIGTSTP/SIGQUIT to the foreground process group, and job control work.
- Wiring stdio: in the child, dup2(slave, 0/1/2) to point stdin/stdout/stderr at the slave, close the original slave fd, set up the environment (TERM=xterm-256color etc.), then execve the shell (/bin/zsh on modern macOS, historically /bin/bash). The shell now behaves exactly as if attached to a hardware terminal.
- The read/write loop is the core: the emulator multiplexes with select()/poll()/kqueue (kqueue on macOS) or a read thread. Bytes read() from the master are the program's output -> feed to the escape-sequence parser -> update screen grid -> redraw. GUI key events -> encode to byte sequences (e.g. arrow up -> ESC[A) -> write() to the master.
- The kernel line discipline does heavy lifting for free: in cooked/canonical mode it buffers a line, handles backspace editing, echoes typed characters, and translates control keys into signals. Full-screen apps (vim, tmux) put the tty into raw mode via tcsetattr/termios so the emulator/app sees every keystroke immediately with no echo and no signal cooking.
- Window size is communicated out-of-band, not in the byte stream: the emulator does ioctl(master, TIOCSWINSZ, &winsize) with rows/cols/pixels. The kernel then sends SIGWINCH to the foreground process so apps re-query size via TIOCGWINSZ and re-layout. Failing to set this leaves programs thinking the terminal is 80x24.
- Child lifecycle: when the shell exits, read() on the master returns EOF/0 (or EIO on Linux) and the parent reaps the child (SIGCHLD/waitpid); the emulator typically closes the window. Closing the master sends SIGHUP to the session, which is how 'hangup' on the controlling terminal kills the shell.
- The emulator is also a state machine on top of the loop: it maintains a 2D grid of cells (char + fg/bg color + attributes), cursor position, scrollback, alternate screen buffer, tab stops, and modes — all mutated by the parsed escape sequences. Rendering that grid is a separate concern from the PTY plumbing.

## How real terminals do it

- xterm (the reference VT implementation): opens the master, forks, sets the slave as controlling terminal, and is the de-facto source of the 'xterm'/'xterm-256color' TERM behavior every other terminal emulates.
- Microsoft's node-pty (used by VS Code's integrated terminal and Hyper): on Unix/macOS it wraps forkpty() in native C++ to spawn the shell and exposes onData/write to JS; on Windows it uses ConPTY. Concrete real-world bug: VS Code PR microsoft/vscode#298993 had to chunk multiline writes because macOS PTYs corrupt input past a ~1024-byte canonical buffer.
- Python's stdlib pty module (pty.fork, pty.spawn) is the minimal teaching example of forking a child onto the slave and copying bytes between master and the real terminal.
- Alacritty and WezTerm (Rust) use the same model: a PTY abstraction (WezTerm's portable-pty crate; Rust's nix/openpty bindings) feeding a VTE parser; Alacritty pulls bytes off the master on a dedicated thread and updates a grid.
- Zellij and tmux are terminal multiplexers that are themselves PTY masters: they forkpty a shell per pane, parse its output into their own grid, then re-emit composited output to the outer real terminal — a PTY inside a PTY. Aram Drevekenin's 'Anatomy of a Terminal Emulator' documents this from the Zellij author's perspective.
- libvterm (used by Neovim's :terminal) is a reusable C library that implements just the parser+grid half, leaving PTY spawning to the host.
- On macOS specifically, Apple's Terminal.app and iTerm2 sit on the same BSD Unix98 /dev/ptmx + /dev/ttysNNN machinery; iTerm2 is a common real-world reference for high-throughput master reads.

## Pitfalls / hard parts

- Controlling-terminal sequencing is fragile: setsid() must come before TIOCSCTTY, and the process must not already be a session leader. Get the order wrong and Ctrl-C, job control, and 'who am I attached to' all silently break. Using login_tty()/forkpty() avoids hand-rolling this.
- Forgetting TIOCSWINSZ / not handling resize: apps default to 80x24 and full-screen TUIs render garbage. You must set winsize on the master and rely on the kernel's SIGWINCH; there are real ordering bugs where SIGWINCH fires before TIOCGWINSZ reports the new size.
- macOS canonical-mode input buffer is only ~1024 bytes — large pastes or multiline input written in one write() to the master get truncated/corrupted (the VS Code bug above). You must chunk writes and/or use bracketed paste.
- Partial/split escape sequences across read() boundaries: a single read() can end in the middle of an ESC[...m sequence. The parser must be a resumable state machine that buffers incomplete sequences, not a per-read regex.
- read()/write() can return short counts, EINTR, or EAGAIN on the nonblocking master; you must loop and handle them. On Linux a closed slave gives EIO on the master read (looks like an error but means 'shell exited'); behavior differs subtly on macOS (EOF), so test both.
- Reaping the child and SIGHUP semantics: if you don't waitpid the exited shell you leak zombies; if you close the master you send SIGHUP to the whole session. Backgrounded children and SIGCHLD must be handled carefully to know when to close the window.
- Backpressure / flow control: a fast-printing program (yes, cat of a big file) can outrun your parser+renderer. Naive blocking reads on the GUI thread freeze the UI; you need a separate read thread/async loop and to apply XON/XOFF or just keep draining. Throughput here is the main thing that separates a toy from a usable terminal.
- Raw vs cooked mode confusion: echo, line editing, and signal generation come from the kernel termios settings on the slave, not from your emulator. Beginners reimplement echo and end up with double characters, or fight the line discipline instead of letting apps set raw mode themselves.
- Mixing master/slave fds: you must close the master in the child and the slave in the parent, or you get fd leaks, missed EOF (read never returns 0 because you still hold a writer), and deadlocks.
- Environment and TERM mismatch: advertising TERM=xterm-256color but not actually implementing those sequences makes apps emit codes you garble onscreen. Pixel-size fields in winsize and locale/UTF-8 handling are commonly forgotten.

## macOS specifics

macOS is BSD-derived and supports Unix98 PTYs via /dev/ptmx (open with posix_openpt) yielding slaves named /dev/ttysNNN; the legacy BSD /dev/pty?? pairs still exist but are deprecated. forkpty()/openpty()/login_tty() live in libutil (<util.h>, not Linux's <pty.h>). Multiplex with kqueue rather than epoll. Two notable gotchas: (1) the canonical-mode input buffer is ~1024 bytes, so large/multiline writes to the master must be chunked (the VS Code node-pty fix); (2) macOS limits the number of PTY devices system-wide (the kern.tty.ptmx_max / pty count limit), which heavy multiplexer use can hit. Apple Terminal.app and iTerm2 both run on this same machinery.

## Sources

- https://en.wikipedia.org/wiki/Pseudoterminal
- https://www.uninformativ.de/blog/postings/2018-02-24/0/POSTING-en.html
- https://movq.de/blog/postings/2018-02-24/0/POSTING-en.html
- https://poor.dev/blog/terminal-anatomy/
- https://man7.org/linux/man-pages/man7/pty.7.html
- https://man7.org/linux/man-pages/man3/openpty.3.html
- https://docs.python.org/3/library/pty.html
- https://cefboud.com/posts/terminals-pty-tty-pyte/
- https://github.com/microsoft/node-pty
- https://github.com/microsoft/vscode/pull/298993
- http://www.gnu.org/s/libc/manual/html_node/Pseudo_002dTerminal-Pairs.html
- https://mikebian.co/how-to-increase-the-macos-terminal-device-limit/
- https://en.wikipedia.org/wiki/Terminal_emulator
