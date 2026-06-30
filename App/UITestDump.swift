#if DEBUG
import Foundation
import SwiftTerm

/// Shared DEBUG harness sink. The XCUITest suite reads these temp files; the
/// custom-drawn terminal view exposes no per-cell text to accessibility, so the
/// headless engine grid is the deterministic content source. Always gated by the
/// `-UITestGridDump` launch argument at the call sites (the app-level timer).
///
/// Split into a grid (content) channel and the window's state (structure)
/// channel so the quick terminal — an accessory hosted outside the main window
/// controllers — can contribute its pane's grid while the multiplexing inventory
/// still comes from a main window, keeping the quake out of the pane/tab counts.
enum UITestDump {
    static let gridDumpPath = "/tmp/xtty-grid-dump.txt"
    static let stateDumpPath = "/tmp/xtty-state-dump.json"

    /// Write a terminal engine's visible grid to the grid-dump file.
    /// `skipNullCellsFollowingWide` + a `characterProvider` keep wide CJK (the NUL
    /// spacer 2nd column) and non-BMP/grapheme emoji (map-indexed codes) intact.
    static func writeGrid(engine: Terminal) {
        var lines: [String] = []
        lines.reserveCapacity(engine.rows)
        for row in 0..<engine.rows {
            lines.append(engine.getLine(row: row)?.translateToString(
                trimRight: true,
                skipNullCellsFollowingWide: true,
                characterProvider: { engine.getCharacter(for: $0) }
            ) ?? "")
        }
        // The dump is the terminal's *physical* rows joined with "\n", so a
        // logical line the terminal soft-wrapped (e.g. text typed at a long
        // prompt) is split across rows. Out-of-process readers asserting on such
        // content use GridDumpReader's wrap-tolerant matcher (ignoringLineWraps).
        do {
            try lines.joined(separator: "\n").write(
                toFile: gridDumpPath, atomically: true, encoding: .utf8)
        } catch {
            // Surface the cause (full /tmp, permissions) instead of leaving a
            // stale dump that reads as a phantom test flake.
            NSLog("[xtty] UITestDump: failed to write grid dump: %@", error.localizedDescription)
        }
    }
}
#endif
