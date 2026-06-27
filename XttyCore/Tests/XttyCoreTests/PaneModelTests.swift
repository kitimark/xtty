import XCTest
import SwiftTerm
@testable import XttyCore

// Unit tests for the view-free multiplexing model: PaneNode split/close/collapse
// transforms and SessionRegistry identity/focus. No app, no views, no PTY — panes
// wrap headless SwiftTerm `Terminal` engines like TerminalSessionTests does.

private final class NoopTerminalDelegate: TerminalDelegate {
    func send(source: Terminal, data: ArraySlice<UInt8>) {}
}

final class PaneModelTests: XCTestCase {
    private let delegate = NoopTerminalDelegate()

    /// Make a fresh registered pane with its own headless session.
    @MainActor
    private func makePane(_ registry: SessionRegistry) -> Pane {
        let engine = Terminal(delegate: delegate)
        let config = ShellResolver.launchConfig(forShell: "/bin/zsh", environment: [:])
        let session = TerminalSession(terminal: engine, launchConfig: config)
        return registry.makePane(for: session)
    }

    // MARK: PaneNode transforms

    @MainActor
    func testSplitWrapsLeafInTwoChildSplit() {
        let r = SessionRegistry()
        let a = makePane(r), b = makePane(r)
        let tree = PaneNode.leaf(a)

        let split = tree.inserting(b, splitting: a.id, axis: .row)

        guard case .split(let axis, let children) = split else {
            return XCTFail("expected a split node")
        }
        XCTAssertEqual(axis, .row)
        XCTAssertEqual(children.count, 2)
        XCTAssertEqual(split.leaves().map(\.id), [a.id, b.id])
    }

    @MainActor
    func testSameAxisSplitStaysNAry() {
        let r = SessionRegistry()
        let a = makePane(r), b = makePane(r), c = makePane(r)

        // Split a→row→b, then split b→row again: should be ONE 3-child row.
        var tree = PaneNode.leaf(a)
        tree = tree.inserting(b, splitting: a.id, axis: .row)
        tree = tree.inserting(c, splitting: b.id, axis: .row)

        guard case .split(.row, let children) = tree else {
            return XCTFail("expected a single row split")
        }
        XCTAssertEqual(children.count, 3, "same-axis split must stay n-ary, not nest")
        XCTAssertEqual(tree.leaves().map(\.id), [a.id, b.id, c.id])
    }

    @MainActor
    func testCrossAxisSplitNests() {
        let r = SessionRegistry()
        let a = makePane(r), b = makePane(r), c = makePane(r)

        var tree = PaneNode.leaf(a)
        tree = tree.inserting(b, splitting: a.id, axis: .row)     // [a | b]
        tree = tree.inserting(c, splitting: b.id, axis: .column)  // b becomes [b / c]

        guard case .split(.row, let rowKids) = tree, rowKids.count == 2 else {
            return XCTFail("expected outer row with 2 children")
        }
        guard case .split(.column, let colKids) = rowKids[1], colKids.count == 2 else {
            return XCTFail("expected b replaced by a column split")
        }
        XCTAssertEqual(tree.leaves().map(\.id), [a.id, b.id, c.id])
    }

    @MainActor
    func testCloseCollapsesSingleChildSplit() {
        let r = SessionRegistry()
        let a = makePane(r), b = makePane(r)
        let tree = PaneNode.leaf(a).inserting(b, splitting: a.id, axis: .row)

        let after = tree.removing(b.id)

        // The 2-child split collapses to the lone survivor leaf.
        guard case .leaf(let survivor)? = after else {
            return XCTFail("expected collapse to a single leaf")
        }
        XCTAssertEqual(survivor.id, a.id)
    }

    @MainActor
    func testCloseLastLeafEmptiesTree() {
        let r = SessionRegistry()
        let a = makePane(r)
        XCTAssertNil(PaneNode.leaf(a).removing(a.id), "removing the only leaf yields nil")
    }

    @MainActor
    func testCloseKeepsNArySplitWhenThreePlus() {
        let r = SessionRegistry()
        let a = makePane(r), b = makePane(r), c = makePane(r)
        var tree = PaneNode.leaf(a)
        tree = tree.inserting(b, splitting: a.id, axis: .row)
        tree = tree.inserting(c, splitting: b.id, axis: .row)

        let after = tree.removing(b.id)

        guard case .split(.row, let kids)? = after, kids.count == 2 else {
            return XCTFail("3-child split should drop to a 2-child split, not collapse")
        }
        XCTAssertEqual(after?.leaves().map(\.id), [a.id, c.id])
    }

    @MainActor
    func testRemovingAbsentIDLeavesTreeUnchanged() {
        let r = SessionRegistry()
        let a = makePane(r), b = makePane(r), ghost = makePane(r)
        let tree = PaneNode.leaf(a).inserting(b, splitting: a.id, axis: .row)
        let after = tree.removing(ghost.id)
        XCTAssertEqual(after?.leaves().map(\.id), [a.id, b.id])
    }

    // MARK: SessionRegistry

    @MainActor
    func testRegistryAllocatesUniqueIDsAndTracksPanes() {
        let r = SessionRegistry()
        let a = makePane(r), b = makePane(r)
        XCTAssertNotEqual(a.id, b.id)
        XCTAssertEqual(Set(r.panes.keys), [a.id, b.id])
        XCTAssertEqual(r.allSessions.count, 2)
    }

    @MainActor
    func testFocusTrackingAndClearOnUnregister() {
        let r = SessionRegistry()
        let a = makePane(r), b = makePane(r)

        r.setFocus(a.id)
        XCTAssertEqual(r.focused, a.id)

        // Focusing an unknown id is ignored (focus never dangles).
        r.setFocus(PaneID(9999))
        XCTAssertEqual(r.focused, a.id)

        // Unregistering the focused pane clears focus; unregistering another doesn't.
        r.setFocus(b.id)
        r.unregister(a.id)
        XCTAssertEqual(r.focused, b.id)
        r.unregister(b.id)
        XCTAssertNil(r.focused)
    }
}
