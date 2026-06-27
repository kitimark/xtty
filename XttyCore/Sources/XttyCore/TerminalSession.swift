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

    public init(terminal: Terminal, launchConfig: ShellLaunchConfig) {
        self.terminal = terminal
        self.launchConfig = launchConfig
    }

    /// Record the shell's exit code. Called by the app's process delegate when
    /// the child process terminates (drives the exit policy).
    public func recordExit(code: Int32?) {
        exitCode = code
    }
}
