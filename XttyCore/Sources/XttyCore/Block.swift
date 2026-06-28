import Foundation

/// The lifecycle state of a command block.
public enum BlockState: String, Equatable, Sendable {
    /// Output is still being produced (command not yet finished).
    case running
    /// Finished with exit code 0 (or no code reported).
    case succeeded
    /// Finished with a non-zero exit code.
    case failed
    /// The command took over the alternate screen (e.g. vim/htop) — not a normal
    /// scrollable command block.
    case opaque
}

/// One captured command: the durable facts a session-progress sidebar needs.
/// Deliberately stores NO screen coordinates (those are unavailable via
/// SwiftTerm's public API and would rot on scrollback trim — see the P4 design).
public struct Block: Equatable, Sendable {
    public let command: String?
    public let exitCode: Int32?
    public let cwd: String?
    public let startedAt: Date
    public let endedAt: Date?
    public let state: BlockState

    public init(command: String?, exitCode: Int32?, cwd: String?, startedAt: Date, endedAt: Date?, state: BlockState) {
        self.command = command
        self.exitCode = exitCode
        self.cwd = cwd
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.state = state
    }
}

/// View-free state machine that turns a stream of OSC 133 marks (plus alternate-
/// screen transitions) into a list of command blocks.
///
/// Rules (P4 design D3): open a block only on `C` (command output start); close
/// only on the first `D` after a `C`, recording the exit code; a prompt with no
/// intervening command produces no block; a stray `D` is a no-op; continuation
/// (`k=s`) prompts don't start commands; while the alternate screen is active,
/// block creation is suppressed, and a command that enters the alternate screen
/// mid-run is finalized as `opaque`.
public final class BlockTracker {
    public private(set) var blocks: [Block] = []
    /// The most recent semantic action seen (for the DEBUG harness dump).
    public private(set) var lastAction: SemanticAction?

    /// The in-flight command, exposed as a `.running` block while a command is
    /// executing — between its output-start (`C`) and command-end (`D`), and not
    /// while suppressed by the alternate screen. `nil` when nothing is running.
    /// Carries the open command's text, cwd, and start time; no end timestamp and
    /// no screen coordinates (the jump anchor is a deferred P4b concern). The
    /// session-progress sidebar reads this to show "running" + a live duration.
    public var runningBlock: Block? {
        guard phase == .running, !isAlternate, let started = openStartedAt else { return nil }
        return Block(
            command: openCommand, exitCode: nil, cwd: openCwd,
            startedAt: started, endedAt: nil, state: .running
        )
    }

    private enum Phase { case idle, atPrompt, running }
    private var phase: Phase = .idle
    private var openCommand: String?
    private var openCwd: String?
    private var openStartedAt: Date?
    private var enteredAltWhileRunning = false
    private var isAlternate = false
    private let now: () -> Date

    public init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    /// Feed a parsed mark, with the session's current working directory (recorded
    /// on the block at command start).
    public func handle(_ mark: SemanticMark, cwd: String?) {
        lastAction = mark.action
        if mark.isContinuation { return }  // PS2 / secondary prompt: not a boundary

        switch mark.action {
        case .promptStart:
            phase = .atPrompt
        case .promptEnd:
            break  // input start; no block change
        case .commandStart:
            if isAlternate { return }  // don't open a block on the alternate screen
            phase = .running
            openCommand = mark.command
            openCwd = cwd
            openStartedAt = now()
            enteredAltWhileRunning = false
        case .commandEnd(let exitCode):
            guard phase == .running, let startedAt = openStartedAt else {
                return  // stray D with no open command — defensive no-op
            }
            let state: BlockState
            if enteredAltWhileRunning {
                state = .opaque
            } else if let code = exitCode {
                state = (code == 0) ? .succeeded : .failed
            } else {
                state = .succeeded
            }
            blocks.append(Block(
                command: openCommand, exitCode: exitCode, cwd: openCwd,
                startedAt: startedAt, endedAt: now(), state: state
            ))
            phase = .atPrompt
            openCommand = nil
            openCwd = nil
            openStartedAt = nil
            enteredAltWhileRunning = false
        }
    }

    /// Feed an alternate-screen transition.
    public func setAlternateScreen(_ isAlt: Bool) {
        isAlternate = isAlt
        if isAlt, phase == .running { enteredAltWhileRunning = true }
    }
}
