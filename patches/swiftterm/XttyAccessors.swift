// XttyAccessors.swift — the P4b-2 SwiftTerm engine addition (DROP-IN, Phase 2).
//
// THIS FILE IS NOT COMPILED BY xtty. It is the committed artifact that the
// Phase-2 light-up drops into the SwiftTerm package's `Sources/SwiftTerm/`
// directory (via the chosen mechanism — a pinned submodule + drop-in, vendored
// source, or a fork; see research/03-analysis/swiftterm-fork-vs-patch-strategy.md
// and openspec change add-spatial-blocks design D1). It is add-only: it modifies
// no existing SwiftTerm file, mirrors the already-public `getScrollInvariantLine`
// idiom, and is the basis for the upstream PR that would retire the local copy.
//
// It exposes the two read-only values P4b-2 needs but that are module-internal
// today: the cursor's trim-invariant absolute row and the scrollback base. Once
// this compiles inside the SwiftTerm module, swap the two seam bodies in
// App/PaneController.swift (engineScrollRow / engineScrollbackBase) to read them.

import Foundation

public extension Terminal {
    /// The cursor's **trim-invariant absolute row**: `buffer.yBase + buffer.y +
    /// buffer.linesTop`. Unlike `getCursorLocation().y` — which is *yBase-relative*
    /// despite its "relative to the visible part of the display" doc comment — this
    /// stays correct regardless of scroll position and survives scrollback trim
    /// (`scroll()` bumps `linesTop` as it trims, keeping `arrayIndex + linesTop`
    /// fixed). Reverse-map it to a current display row with `row − scrollbackBase`.
    /// Pinned to the normal buffer's coordinates via the live `buffer` (callers gate
    /// capture on the alternate screen, so this is read on the normal buffer).
    ///
    /// Sibling to the existing public `getScrollInvariantLine(row:)`.
    func getScrollInvariantCursorLocation() -> Position {
        Position(col: buffer.x, row: buffer.yBase + buffer.y + buffer.linesTop)
    }

    /// The monotonic scrollback base (`buffer.linesTop`): the number of lines that
    /// have scrolled off the top. Used to reverse-map an absolute row to the
    /// current display row (`absoluteRow − scrollbackBase`) and — via `liveTop =
    /// yBase + linesTop` — to detect a clear/reset (a drop in its high-water mark).
    var scrollbackBase: Int { buffer.linesTop }
}
