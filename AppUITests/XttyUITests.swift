import XCTest
import AppKit

/// macOS XCUITest coverage for xtty's terminal window.
///
/// The terminal is SwiftTerm's custom-drawn LocalProcessTerminalView: AppKit
/// exposes no per-cell text to accessibility. So these tests assert content two
/// ways: (1) XCTAttachment screenshots for human/vision review, and (2) a DEBUG
/// grid-dump file (/tmp/xtty-grid-dump.txt) for deterministic substring checks
/// when the app is launched with "-UITestGridDump". Without the dump hook (e.g.
/// a Release build) the substring assertions are skipped and screenshots remain
/// the record.
final class XttyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        GridDumpReader.reset()
        app = XCUIApplication()
        app.launchArguments = ["-UITestGridDump"]
        app.launch()
        XCTAssertTrue(app.terminal.waitForExistence(timeout: 10),
                      "terminal view (id=\(XttyUI.terminalIdentifier)) never appeared")
        // Wait for the shell prompt to draw so we type into a ready shell.
        GridDumpReader.waitForNonEmpty(timeout: 10)
    }

    override func tearDownWithError() throws {
        attachScreenshot("final-state-\(name)")
        app.terminate()
        app = nil
    }

    // 1. Focus-typing on activate WITHOUT clicking inside the view.
    func testFocusTypingOnActivateWithoutClicking() throws {
        app.activate() // ensure frontmost; deliberately NO terminal.click()
        XCTAssertTrue(app.mainWindow.waitForExistence(timeout: 5))

        let marker = "XTTYFOCUS\(Int.random(in: 1000...9999))"
        app.typeText(marker) // routes to focused responder, no tap/click first

        attachScreenshot("focus-typing-typed")
        attachGridDump("focus-typing-grid")

        if GridDumpReader.isAvailable {
            XCTAssertTrue(GridDumpReader.waitForContains(marker, timeout: 5),
                          "typed marker never reached the grid - focus-on-activate failed")
        } else {
            XCTAssertTrue(app.mainWindow.exists)
        }
        app.typeKey("u", modifierFlags: .control) // clear staged input
    }

    // 2. Multi-line paste is INSERTED, not auto-executed.
    func testMultiLinePasteIsNotAutoExecuted() throws {
        let tag = Int.random(in: 1000...9999)
        let lineA = "alpha\(tag)"
        let lineB = "beta\(tag)"

        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString("\(lineA)\n\(lineB)", forType: .string)

        app.activate()
        app.typeKey("v", modifierFlags: .command) // Cmd+V; DO NOT press Return

        attachScreenshot("paste-staged-before-return")
        attachGridDump("paste-grid")

        if GridDumpReader.isAvailable {
            XCTAssertTrue(GridDumpReader.waitForContains(lineA, timeout: 5),
                          "first pasted line missing from grid")
            XCTAssertTrue(GridDumpReader.waitForContains(lineB, timeout: 5),
                          "second pasted line missing (multi-line paste not inserted)")
            let grid = GridDumpReader.read() ?? ""
            XCTAssertFalse(grid.lowercased().contains("command not found"),
                           "pasted text appears to have been executed")
        } else {
            XCTAssertTrue(app.mainWindow.exists)
        }
        app.typeKey("u", modifierFlags: .control) // clear staged input
    }

    // 3. Window resize redraw smoke.
    func testWindowResizeRedrawSmoke() throws {
        app.activate()
        let marker = "XTTYSIZE\(Int.random(in: 1000...9999))"
        app.typeText(marker) // leave a visible token (do not execute)
        if GridDumpReader.isAvailable { GridDumpReader.waitForContains(marker, timeout: 5) }
        attachScreenshot("resize-before")

        let window = app.mainWindow
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        let before = window.frame

        let corner = window.coordinate(withNormalizedOffset: CGVector(dx: 1.0, dy: 1.0))
        let target = corner.withOffset(CGVector(dx: -160, dy: -120))
        corner.click(forDuration: 0.2, thenDragTo: target)

        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        attachScreenshot("resize-after")
        attachGridDump("resize-grid")

        XCTAssertTrue(app.terminal.exists, "terminal disappeared after resize")
        XCTAssertTrue(window.exists, "window disappeared after resize")
        if before == window.frame {
            XCTContext.runActivity(named: "window frame unchanged after drag") { _ in }
        }
        if GridDumpReader.isAvailable {
            XCTAssertTrue(GridDumpReader.waitForContains(marker, timeout: 5),
                          "content lost across resize redraw")
        }
        app.typeKey("u", modifierFlags: .control) // clear staged input
    }

    // 4. Basic typed echo.
    func testBasicTypedEcho() throws {
        app.activate()
        let token = "XTTYECHO\(Int.random(in: 1000...9999))"
        app.typeText("printf '%s\\n' \(token)")
        attachScreenshot("echo-command-typed")
        app.typeKey(.enter, modifierFlags: []) // Return

        attachScreenshot("echo-after-return")
        attachGridDump("echo-grid")

        if GridDumpReader.isAvailable {
            XCTAssertTrue(GridDumpReader.waitForContains(token, timeout: 5),
                          "echoed output never appeared in the grid")
        } else {
            XCTAssertTrue(app.mainWindow.exists)
        }
    }
}
