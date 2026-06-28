import Foundation

/// View-free spatial navigation over command blocks (P4b-2): converting an
/// absolute (trim-invariant) anchor row to a current display row, choosing the
/// previous/next prompt to jump to relative to the viewport, and computing the
/// copy range for a block's output. All pure `Int` math — the app supplies the
/// engine coordinates (or `nil` when the provider is unavailable) and performs the
/// actual scroll / text extraction.
public enum BlockNavigation {

    /// Direction for jump-to-prompt.
    public enum JumpDirection: Sendable { case previous, next }

    /// Result of reverse-mapping an absolute anchor row to a display-buffer row.
    public enum DisplayRow: Equatable, Sendable {
        /// A valid display-buffer row (a `scrollTo(row:)` argument).
        case row(Int)
        /// The anchored row has scrolled out of the bounded scrollback (it is
        /// below the current `scrollbackBase`), so it can no longer be shown.
        case trimmedOut
    }

    /// Reverse-map an absolute, trim-invariant row to the current display-buffer
    /// row: `displayRow = absoluteRow − scrollbackBase`. A negative result means
    /// the row was trimmed out of the buffer.
    public static func displayRow(forAbsolute absoluteRow: Int, scrollbackBase: Int) -> DisplayRow {
        let r = absoluteRow - scrollbackBase
        return r < 0 ? .trimmedOut : .row(r)
    }

    /// Choose the absolute prompt row to jump to, relative to the current viewport
    /// top — stateless, matching established terminals (jump is relative to where
    /// you are, not a stored cursor).
    ///
    /// - `promptRows`: the absolute prompt rows of anchored, still-valid blocks.
    ///   Order/uniqueness need not be supplied; this sorts internally.
    /// - `currentTopAbsolute`: the absolute row at the viewport's top
    ///   (`getTopVisibleRow() + scrollbackBase`).
    /// - `.previous` → the greatest prompt row strictly above the viewport top;
    ///   `.next` → the smallest prompt row strictly below it.
    ///
    /// Returns `nil` when there is no prompt in that direction (a graceful no-op
    /// upstream).
    public static func jumpTargetRow(
        promptRows: [Int],
        currentTopAbsolute: Int,
        direction: JumpDirection
    ) -> Int? {
        switch direction {
        case .previous:
            return promptRows.filter { $0 < currentTopAbsolute }.max()
        case .next:
            return promptRows.filter { $0 > currentTopAbsolute }.min()
        }
    }

    /// The half-open absolute row range `[start, end]` to copy for a block's
    /// output, excluding the trailing prompt (iTerm2's BEFORE_OUTPUT→BEFORE_PROMPT):
    /// from the output-start anchor (`C`) through the output-end anchor (`D`). For a
    /// still-running block, pass the live cursor row as `liveEnd` (its anchor has no
    /// `outputEnd` yet). Returns `nil` when the start is unknown or the range is
    /// degenerate (start beyond end), so copy no-ops rather than grabbing nothing.
    public static func outputRowRange(
        anchor: BlockAnchor,
        liveEnd: Int? = nil
    ) -> (start: Int, end: Int)? {
        guard let start = anchor.outputStart else { return nil }
        guard let end = anchor.outputEnd ?? liveEnd else { return nil }
        guard end >= start else { return nil }
        return (start, end)
    }
}
