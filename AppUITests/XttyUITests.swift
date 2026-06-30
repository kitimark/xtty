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
            // Wrap-tolerant: on CI a long shell prompt soft-wraps the marker
            // across physical rows, which the dump joins with "\n". The marker
            // still reached the focused pane (focus works), so match across the
            // wrap; a genuinely absent marker still fails the assertion.
            XCTAssertTrue(GridDumpReader.waitForContains(marker, timeout: 5, ignoringLineWraps: true),
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

    // 5. Find bar: Cmd+F opens it, a query locates a match, Escape dismisses and
    //    restores terminal focus (task 6.1). SwiftTerm's find bar sets no a11y
    //    identifiers, so we match its NSSearchField + the "Aa" option checkbox
    //    (a real AXTitle). The highlight itself is render-only (not in the grid
    //    text) → captured via screenshot; existence + dismissal + focus-restore
    //    are the deterministic assertions.
    func testFindBarOpensLocatesAndDismisses() throws {
        app.activate()
        let token = "FINDME\(Int.random(in: 1000...9999))"
        app.typeText("printf '%s\\n' \(token)")
        app.typeKey(.enter, modifierFlags: [])
        if GridDumpReader.isAvailable {
            XCTAssertTrue(GridDumpReader.waitForContains(token, timeout: 5),
                          "seed token never reached the grid")
        }

        // Cmd+F → the AppKit Find menu → SwiftTerm's native bar. Fall back to
        // clicking the menu item if the synthetic key-equivalent doesn't register.
        app.typeKey("f", modifierFlags: .command)
        let searchField = app.searchFields.firstMatch
        if !searchField.waitForExistence(timeout: 3) {
            app.menuItems["Find…"].click()
        }
        let caseToggle = app.checkBoxes["Aa"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5),
                      "find bar search field never appeared after Cmd+F")
        XCTAssertTrue(caseToggle.waitForExistence(timeout: 2),
                      "find bar option checkbox (Aa) missing")
        attachScreenshot("find-bar-open")

        // showFindBar makes the search field first responder, so typing lands in it.
        app.typeText(token)
        attachScreenshot("find-query-located")

        // Escape dismisses the bar (it's only hidden, so assert it leaves queries).
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(caseToggle.waitForNonExistence(timeout: 3),
                      "find bar should be hidden after Escape")

        // Focus restored: a typed marker must reach the terminal grid, not a field.
        let marker = "AFTERFIND\(Int.random(in: 1000...9999))"
        app.typeText(marker)
        attachGridDump("find-focus-restored-grid")
        if GridDumpReader.isAvailable {
            XCTAssertTrue(GridDumpReader.waitForContains(marker, timeout: 5),
                          "focus did not return to the terminal after dismissing find")
        }
        app.typeKey("u", modifierFlags: .control) // clear staged marker
    }

    // 6. Truecolor + emoji + wide chars (task 6.3). Color is render-only (no
    //    color in the grid text) → screenshot; emoji/CJK text is asserted from
    //    the (fixed) grid dump. Non-ASCII is driven through the shell — typed as
    //    ASCII printf bytes for color, pasted as literal UTF-8 for emoji/CJK —
    //    because XCUITest typeText is unreliable for emoji/CJK.
    //    Ligatures: SwiftTerm's default CoreText grid path applies no ligature
    //    substitution, so for P2 this is a no-op (recorded finding, not asserted).
    func testTruecolorEmojiAndWideChars() throws {
        app.activate()
        let tag = Int.random(in: 1000...9999)

        // 24-bit truecolor via an SGR escape (typed ASCII). The text "ORANGE<tag>"
        // lands in the grid; the orange color is verified in the screenshot.
        app.typeText("printf '\\033[38;2;255;110;0mORANGE\(tag)\\033[0m\\n'")
        app.typeKey(.enter, modifierFlags: [])
        if GridDumpReader.isAvailable {
            XCTAssertTrue(GridDumpReader.waitForContains("ORANGE\(tag)", timeout: 5),
                          "truecolor line text missing (color itself is screenshot-verified)")
        }

        // Emoji + wide CJK as literal UTF-8 via the pasteboard (avoids typeText).
        let i18n = "echo ROCKET\(tag) 🚀 日本語 ✅"
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(i18n, forType: .string)
        app.typeKey("v", modifierFlags: .command)
        app.typeKey(.enter, modifierFlags: [])

        attachScreenshot("i18n-truecolor-emoji-wide")
        attachGridDump("i18n-grid")

        if GridDumpReader.isAvailable {
            XCTAssertTrue(GridDumpReader.waitForContains("🚀", timeout: 5),
                          "non-BMP emoji (🚀) missing from grid — characterProvider not applied?")
            XCTAssertTrue(GridDumpReader.waitForContains("日本語", timeout: 5),
                          "wide CJK garbled/missing — skipNullCellsFollowingWide not applied?")
            XCTAssertTrue(GridDumpReader.waitForContains("✅", timeout: 5),
                          "BMP emoji (✅) missing from grid")
        } else {
            XCTAssertTrue(app.mainWindow.exists)
        }
    }
}
