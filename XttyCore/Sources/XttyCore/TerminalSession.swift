import Foundation
import SwiftTerm

/// A single terminal session: the seam anchor between xtty logic and the
/// terminal engine.
///
/// `TerminalSession` holds an **observe-only** handle to SwiftTerm's headless
/// `Terminal` engine (obtained from the view's `getTerminal()`), the launch
/// configuration used to start the shell, and the process exit status once the
/// shell terminates. It deliberately does NOT drive the engine — the SwiftTerm
/// view + PTY feed bytes into it. xtty logic reads through this object.
///
/// This is the unit that P3 (tabs/splits) will multiply: today one window owns
/// one session; later one window owns N. Introducing it now keeps that growth a
/// matter of counting sessions rather than retrofitting a session type.
///
/// Invariant: `XttyCore` references only the headless `Terminal` engine, never a
/// concrete terminal view type. The view lives in the app target.
public final class TerminalSession {
    /// Observe-only handle to the terminal engine (grid + parser state).
    public let terminal: Terminal

    /// How the shell for this session was launched.
    public let launchConfig: ShellLaunchConfig

    /// The shell's exit code, set once the process terminates (`nil` while
    /// running, and `nil` if the process ended without a reported code).
    public private(set) var exitCode: Int32?

    /// The shell's most recently reported working directory (from OSC 7),
    /// decoded; `nil` until the shell first reports one (callers fall back to the
    /// launch directory). Distinct from `launchConfig.cwd` (the static start dir).
    public private(set) var currentWorkingDirectory: OSC7.WorkingDirectory?

    /// The command blocks captured from OSC 133 (the P5 sidebar reads these).
    public let blocks = BlockTracker()

    /// Whether the session's terminal is currently on the alternate screen
    /// (mirrors the engine's `isCurrentBufferAlternate`).
    public private(set) var isAlternateScreen = false

    public init(terminal: Terminal, launchConfig: ShellLaunchConfig) {
        self.terminal = terminal
        self.launchConfig = launchConfig
    }

    /// Record the shell's exit code. Called by the app's process delegate when
    /// the child process terminates (drives the exit policy).
    public func recordExit(code: Int32?) {
        exitCode = code
    }

    /// Record a working directory reported via OSC 7 (already decoded).
    public func updateWorkingDirectory(_ wd: OSC7.WorkingDirectory) {
        currentWorkingDirectory = wd
    }

    /// Feed a parsed OSC 133 mark into the block tracker, tagging it with the
    /// session's current working directory and the engine's trim-invariant absolute
    /// cursor row at this mark (`row` is `nil` when the coordinate provider is
    /// unavailable — the Phase-1 seam — so the block simply gets no anchor).
    public func handleSemanticMark(_ mark: SemanticMark, row: Int? = nil) {
        blocks.handle(mark, cwd: liveLocalDirectory ?? launchConfig.cwd, row: row)
    }

    /// Record an alternate-screen transition (drives block suppression).
    public func setAlternateScreen(_ isAlt: Bool) {
        isAlternateScreen = isAlt
        blocks.setAlternateScreen(isAlt)
    }

    /// The session's at-a-glance activity for the progress sidebar (H1), derived
    /// from the block tracker (running / last finished) and the alternate-screen
    /// flag. Pure read of existing state — no engine calls.
    public var activity: SessionActivity {
        SessionActivity.derive(
            isAlternateScreen: isAlternateScreen,
            isRunning: blocks.runningBlock != nil,
            lastFinished: blocks.blocks.last?.state
        )
    }

    /// The text of the command currently running (when known), else `nil`.
    public var runningCommand: String? {
        blocks.runningBlock?.command
    }

    /// The best-known *local* directory to start a new pane in: the live cwd when
    /// it is on the local machine, else `nil` (so callers fall back to the
    /// inherited profile's launch directory). A remote cwd (e.g. over ssh) yields
    /// `nil` rather than a path that doesn't exist locally.
    public var liveLocalDirectory: String? {
        guard let cwd = currentWorkingDirectory, !cwd.isRemote else { return nil }
        return cwd.path
    }
}
