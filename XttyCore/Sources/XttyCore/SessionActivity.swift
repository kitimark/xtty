import Foundation

/// The at-a-glance activity state of a *session* for the progress sidebar (H1).
///
/// Distinct from per-block `BlockState`: this folds the whole session's recent
/// history plus the alternate-screen flag into one summary the sidebar renders.
/// View-free and purely derived (see `derive`) so it is unit-testable without a
/// terminal view.
public enum SessionActivity: String, Equatable, Sendable {
    /// Nothing has run yet, or the session is sitting at a fresh prompt.
    case idle
    /// A command is currently executing.
    case running
    /// The most recent finished command exited 0.
    case succeeded
    /// The most recent finished command exited non-zero.
    case failed
    /// A full-screen application owns the screen (alternate buffer).
    case fullScreen

    /// Derive the session activity with a fixed precedence (design D1):
    /// fullScreen → running → failed → succeeded → idle.
    ///
    /// - Parameters:
    ///   - isAlternateScreen: whether the session is on the alternate buffer.
    ///   - isRunning: whether a command is currently in flight.
    ///   - lastFinished: the state of the most recent *finished* block, if any.
    public static func derive(
        isAlternateScreen: Bool,
        isRunning: Bool,
        lastFinished: BlockState?
    ) -> SessionActivity {
        if isAlternateScreen { return .fullScreen }
        if isRunning { return .running }
        switch lastFinished {
        case .failed: return .failed
        case .succeeded: return .succeeded
        // nil (nothing run), .opaque (a finished full-screen excursion), or the
        // transient .running all read as "back at the prompt" → idle.
        case .opaque, .running, .none: return .idle
        }
    }
}
