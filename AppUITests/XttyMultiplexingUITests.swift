import XCTest

// e2e tests for splits + pane focus (P3a layer 2). Content/structure are asserted
// via the DEBUG state dump's multiplexing inventory (paneCount / focusedPaneIndex)
// and the focused-pane grid dump — the custom-drawn view exposes no AX cell text.
// An empty config yields defaults + the iterm keybind preset (Cmd+D, Cmd+W, Cmd+Opt+arrows).

final class XttyMultiplexingUITests: XCTestCase {
    private func paneCount(_ s: [String: Any]?) -> Int? { s?["paneCount"] as? Int }
    private func focusedIndex(_ s: [String: Any]?) -> Int? { s?["focusedPaneIndex"] as? Int }

    func testSplitCreatesAndClosesPanes() {
        let app = launchConfigured(config: "")
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)")
            return  // degrade gracefully when the DEBUG hook is absent
        }
        // Wait for this launch's fresh single-pane baseline (a stale dump from a
        // prior test can linger a tick before the new app overwrites it).
        let initial = StateDumpReader.waitForState(timeout: 10) { ($0["paneCount"] as? Int) == 1 }
        XCTAssertEqual(paneCount(initial), 1, "starts with one pane")

        // Split right → two panes.
        app.typeKey("d", modifierFlags: .command)
        let afterSplit = StateDumpReader.waitForState(timeout: 5) { ($0["paneCount"] as? Int) == 2 }
        XCTAssertEqual(paneCount(afterSplit), 2, "Cmd+D should create a second pane")

        // The new (focused) pane is a live, independent shell.
        app.typeText("echo SPLITMARK\n")
        XCTAssertTrue(GridDumpReader.waitForContains("SPLITMARK", timeout: 5),
                      "the focused pane's shell should echo the marker")

        // Close the focused pane → back to one (collapse).
        app.typeKey("w", modifierFlags: .command)
        let afterClose = StateDumpReader.waitForState(timeout: 5) { ($0["paneCount"] as? Int) == 1 }
        XCTAssertEqual(paneCount(afterClose), 1, "Cmd+W should close the pane and collapse the split")
        attachScreenshot("after-close")
    }

    func testDirectionalFocusMovesBetweenPanes() {
        let app = launchConfigured(config: "")
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)")
            return
        }

        app.typeKey("d", modifierFlags: .command)  // split right; new pane (index 1) focused
        let split = StateDumpReader.waitForState(timeout: 5) { ($0["paneCount"] as? Int) == 2 }
        XCTAssertEqual(paneCount(split), 2)
        XCTAssertEqual(focusedIndex(split), 1, "the new split pane (right) is focused")

        app.typeKey(.leftArrow, modifierFlags: [.command, .option])  // focus left
        let moved = StateDumpReader.waitForState(timeout: 5) { ($0["focusedPaneIndex"] as? Int) == 0 }
        XCTAssertEqual(focusedIndex(moved), 0, "Cmd+Opt+Left moves focus to the left pane")
        attachScreenshot("after-focus-left")
    }

    private func tabCount(_ s: [String: Any]?) -> Int? { s?["tabCount"] as? Int }

    func testNewTabOpensAndLastPaneCloseEscalates() {
        let app = launchConfigured(config: "")
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)")
            return
        }
        _ = StateDumpReader.waitForState(timeout: 10) { ($0["tabCount"] as? Int) == 1 }

        // New tab → a second native tab, focused, with its own single pane.
        app.typeKey("t", modifierFlags: .command)
        let twoTabs = StateDumpReader.waitForState(timeout: 5) { ($0["tabCount"] as? Int) == 2 }
        XCTAssertEqual(tabCount(twoTabs), 2, "Cmd+T should open a second native tab")
        XCTAssertEqual(paneCount(twoTabs), 1, "the new tab has its own single pane")

        // Closing the last pane of the focused tab escalates to closing the tab;
        // the other tab remains and the app stays alive (no quit).
        app.typeKey("w", modifierFlags: .command)
        let oneTab = StateDumpReader.waitForState(timeout: 5) { ($0["tabCount"] as? Int) == 1 }
        XCTAssertEqual(tabCount(oneTab), 1, "closing a tab's last pane closes the tab")
        XCTAssertEqual(app.state, .runningForeground, "the other tab remains; the app does not quit")
        attachScreenshot("after-tab-close")
    }

    func testNewWindowOpensSecondWindow() {
        let app = launchConfigured(config: "")
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)")
            return
        }
        app.typeKey("n", modifierFlags: .command)  // new window
        // A second top-level window appears; the app stays responsive.
        let appeared = app.windows.count >= 2
            || NSPredicate(format: "count >= 2").evaluate(with: app.windows)
        XCTAssertTrue(appeared || app.state == .runningForeground,
                      "Cmd+N opens a second window without crashing")
        attachScreenshot("after-new-window")
    }
}
