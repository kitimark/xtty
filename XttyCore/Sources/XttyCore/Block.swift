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

/// A best-effort, scroll-invariant anchor for a command block (P4b-2). The rows
/// are absolute, trim-invariant buffer rows (`buffer.yBase + y + linesTop`) read
/// from the engine at the OSC 133 marks: `promptRow` at `A`, `outputStart` at `C`,
/// `outputEnd` at `D`. They are OPTIONAL — `nil` when the engine coordinate
/// provider is unavailable (the Phase-1 seam returns `nil`) or while suppressed by
/// the alternate screen — so anchored operations degrade gracefully. `epoch` is
/// the session's invalidation generation at capture time; an anchor whose epoch no
/// longer matches the session's current epoch is stale (resize/reflow/reset) and
/// MUST NOT be used (see `BlockTracker.anchorIsValid`).
public struct BlockAnchor: Equatable, Sendable {
    public let epoch: Int
    public let promptRow: Int?
    public let outputStart: Int?
    public let outputEnd: Int?

    public init(epoch: Int, promptRow: Int? = nil, outputStart: Int? = nil, outputEnd: Int? = nil) {
        self.epoch = epoch
        self.promptRow = promptRow
        self.outputStart = outputStart
        self.outputEnd = outputEnd
    }
}

/// One captured command: the durable facts a session-progress sidebar needs, plus
/// an OPTIONAL best-effort scroll-invariant `anchor` (P4b-2) for jump/copy. The
/// durable fields store NO screen coordinates (P4a); the anchor, when present, is a
/// trim-invariant absolute row that survives scrollback trim and is invalidated on
/// resize/reflow/reset — additive, never required for a block to be valid.
public struct Block: Equatable, Sendable {
    public let command: String?
    public let exitCode: Int32?
    public let cwd: String?
    public let startedAt: Date
    public let endedAt: Date?
    public let state: BlockState
    public let anchor: BlockAnchor?

    public init(command: String?, exitCode: Int32?, cwd: String?, startedAt: Date, endedAt: Date?, state: BlockState, anchor: BlockAnchor? = nil) {
        self.command = command
        self.exitCode = exitCode
        self.cwd = cwd
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.state = state
        self.anchor = anchor
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
    /// Carries the open command's text, cwd, start time, and a best-effort anchor
    /// (prompt + output-start rows; no output-end yet — copy of a running command
    /// uses the live cursor row for the end). The sidebar reads this for "running".
    public var runningBlock: Block? {
        guard phase == .running, !isAlternate, let started = openStartedAt else { return nil }
        return Block(
            command: openCommand, exitCode: nil, cwd: openCwd,
            startedAt: started, endedAt: nil, state: .running,
            anchor: anchor(promptRow: openPromptRow, outputStart: openOutputStart, outputEnd: nil, epoch: openEpoch)
        )
    }

    /// The session's invalidation generation. Anchors are stamped with the epoch
    /// current at their capture; a resize/reflow (`bumpEpoch`) or a detected
    /// clear/reset (`noteLiveTop` high-water drop) bumps it so older anchors become
    /// stale. Read by `anchorIsValid`.
    public private(set) var currentEpoch: Int = 0

    private enum Phase { case idle, atPrompt, running }
    private var phase: Phase = .idle
    private var openCommand: String?
    private var openCwd: String?
    private var openStartedAt: Date?
    private var openPromptRow: Int?
    private var openOutputStart: Int?
    private var openEpoch: Int = 0
    private var pendingPromptRow: Int?
    private var enteredAltWhileRunning = false
    private var isAlternate = false
    private var liveTopHighWater: Int?
    private let now: () -> Date

    /// Upper bound on the retained finished-block history (lean-memory, P4b-3).
    /// The oldest blocks are dropped beyond this; the running block is exposed
    /// separately and is never affected by trimming.
    private let maxBlocks: Int

    public init(now: @escaping () -> Date = Date.init, maxBlocks: Int = 1000) {
        self.now = now
        self.maxBlocks = max(1, maxBlocks)
    }

    /// Feed a parsed mark, with the session's current working directory (recorded
    /// on the block at command start) and the engine's trim-invariant absolute
    /// cursor row at this mark (`nil` when the coordinate provider is unavailable —
    /// the Phase-1 seam — so the block simply gets no anchor).
    public func handle(_ mark: SemanticMark, cwd: String?, row: Int? = nil) {
        lastAction = mark.action
        if mark.isContinuation { return }  // PS2 / secondary prompt: not a boundary

        switch mark.action {
        case .promptStart:
            phase = .atPrompt
            pendingPromptRow = isAlternate ? nil : row  // remember for the block that opens at C
        case .promptEnd:
            break  // input start; no block change
        case .commandStart:
            if isAlternate { return }  // don't open a block on the alternate screen
            phase = .running
            openCommand = mark.command
            openCwd = cwd
            openStartedAt = now()
            openPromptRow = pendingPromptRow
            openOutputStart = row
            openEpoch = currentEpoch
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
            // An alt-screen excursion is not a scrollable block → no anchor.
            let anchor = enteredAltWhileRunning
                ? nil
                : anchor(promptRow: openPromptRow, outputStart: openOutputStart, outputEnd: row, epoch: openEpoch)
            blocks.append(Block(
                command: openCommand, exitCode: exitCode, cwd: openCwd,
                startedAt: startedAt, endedAt: now(), state: state, anchor: anchor
            ))
            if blocks.count > maxBlocks {
                blocks.removeFirst(blocks.count - maxBlocks)  // drop oldest, keep newest-N
            }
            phase = .atPrompt
            openCommand = nil
            openCwd = nil
            openStartedAt = nil
            openPromptRow = nil
            openOutputStart = nil
            pendingPromptRow = nil
            enteredAltWhileRunning = false
        }
    }

    /// Feed an alternate-screen transition.
    public func setAlternateScreen(_ isAlt: Bool) {
        isAlternate = isAlt
        if isAlt, phase == .running { enteredAltWhileRunning = true }
    }

    // MARK: Anchor invalidation (P4b-2)

    /// Invalidate every existing anchor — call on a resize/reflow/scrollback-size
    /// change (signalled by the engine's `sizeChanged`), which shifts buffer line
    /// indices without dropping `linesTop`, so absolute rows would silently
    /// mis-resolve. Conservative: also drops still-valid anchors on a window grow
    /// (acceptable; jump/copy of old blocks resumes after new commands run).
    public func bumpEpoch() {
        currentEpoch &+= 1
    }

    /// Sample the engine's `liveTop` (`yBase + linesTop`), which is monotonic
    /// across normal output and drops on a clear/reset (`linesTop → 0`). A drop
    /// below the high-water mark bumps the epoch (invalidating pre-reset anchors).
    /// `nil` (provider unavailable) is ignored. Best-effort: a clear immediately
    /// followed by a large flood within one feed chunk may mask the drop.
    ///
    /// Returns `true` when this sample bumped the epoch (a clear/reset was
    /// detected), so the caller can refresh epoch-dependent UI (the block
    /// sidebar's stale-dimming, P4b-3) only on a real invalidation rather than
    /// on every scroll tick.
    @discardableResult
    public func noteLiveTop(_ liveTop: Int?) -> Bool {
        guard let liveTop else { return false }
        if let hw = liveTopHighWater, liveTop < hw {
            bumpEpoch()
            liveTopHighWater = liveTop  // re-baseline from the post-reset level
            return true
        }
        liveTopHighWater = max(liveTopHighWater ?? liveTop, liveTop)
        return false
    }

    /// Whether an anchor is still usable (its epoch matches the current epoch).
    public func anchorIsValid(_ anchor: BlockAnchor) -> Bool {
        anchor.epoch == currentEpoch
    }

    /// Build a best-effort anchor, or `nil` when no row was captured (provider
    /// unavailable) so a block stays valid without coordinates.
    private func anchor(promptRow: Int?, outputStart: Int?, outputEnd: Int?, epoch: Int) -> BlockAnchor? {
        if promptRow == nil, outputStart == nil, outputEnd == nil { return nil }
        return BlockAnchor(epoch: epoch, promptRow: promptRow, outputStart: outputStart, outputEnd: outputEnd)
    }
}
