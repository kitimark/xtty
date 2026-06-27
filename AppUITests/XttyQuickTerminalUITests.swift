import XCTest

// e2e test for the quick terminal (quake), driven via the DEBUG "Toggle Quick
// Terminal" menu action — a real global hotkey can't be synthesized by XCUITest.
// Asserts the panel shows + accepts typed text (its grid dump) and stays excluded
// from the main multiplexing inventory (pane/tab counts).

final class XttyQuickTerminalUITests: XCTestCase {
    private func paneCount(_ s: [String: Any]?) -> Int? { s?["paneCount"] as? Int }
    private func tabCount(_ s: [String: Any]?) -> Int? { s?["tabCount"] as? Int }

    private static let config = """
    quick-terminal = true
    quick-terminal-hotkey = ctrl+opt+grave
    """

    /// Trigger the DEBUG toggle from the menu bar. Returns false if the menu is
    /// absent (a Release build), so the test degrades gracefully.
    private func toggleQuickTerminal(_ app: XCUIApplication) -> Bool {
        let debug = app.menuBars.menuBarItems["Debug"]
        guard debug.waitForExistence(timeout: 5) else { return false }
        debug.click()
        let item = app.menuBars.menuItems["Toggle Quick Terminal"]
        guard item.waitForExistence(timeout: 5) else { return false }
        item.click()
        return true
    }

    func testQuickTerminalSummonTypeHideStaysExcluded() {
        let app = launchConfigured(config: Self.config)
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)")
            return  // degrade gracefully when the DEBUG hook is absent
        }

        // Baseline: one main window, one pane, one tab; quake not yet summoned.
        let baseline = StateDumpReader.waitForState(timeout: 10) {
            ($0["paneCount"] as? Int) == 1 && ($0["tabCount"] as? Int) == 1
        }
        XCTAssertEqual(paneCount(baseline), 1, "starts with one main pane")
        XCTAssertEqual(tabCount(baseline), 1, "starts with one tab")

        // Summon the quake via the DEBUG toggle (== the global-hotkey path).
        guard toggleQuickTerminal(app) else {
            attachScreenshot("no-debug-menu (Release?)")
            return
        }

        // The quake's scratch shell draws a prompt and accepts typed text. While
        // the panel is key, the app's dump timer writes the quake pane's grid.
        XCTAssertTrue(GridDumpReader.waitForNonEmpty(timeout: 10),
                      "the quake shell should draw a prompt")
        app.typeText("echo QUAKEMARK\n")
        XCTAssertTrue(GridDumpReader.waitForContains("QUAKEMARK", timeout: 10),
                      "the quake pane's shell should echo the typed marker")

        // The quake is an accessory: the main inventory is unaffected (its private
        // registry keeps it out of the pane/tab counts). Wait for a fresh snapshot
        // (rather than a bare read) so a missing dump gives a clear failure.
        let whileShown = StateDumpReader.waitForState(timeout: 5)
        XCTAssertEqual(paneCount(whileShown), 1, "the quake is not counted as a main pane")
        XCTAssertEqual(tabCount(whileShown), 1, "the quake is not counted as a tab")
        attachScreenshot("quake-shown")

        // Hide on a second toggle; the app stays alive, inventory stays 1/1.
        XCTAssertTrue(toggleQuickTerminal(app), "second toggle hides the quake")
        let afterHide = StateDumpReader.waitForState(timeout: 5) {
            ($0["paneCount"] as? Int) == 1 && ($0["tabCount"] as? Int) == 1
        }
        XCTAssertEqual(paneCount(afterHide), 1, "main inventory unchanged after hide")
        XCTAssertEqual(app.state, .runningForeground, "the app stays alive after hiding the quake")
        attachScreenshot("quake-hidden")
    }
}
