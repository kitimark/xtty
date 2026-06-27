import XCTest
import AppKit

/// XCUITest coverage for config application + bounded scrollback (task 6.2).
///
/// Unlike `XttyUITests`, these tests launch the app with a *specific* config file
/// injected via `XDG_CONFIG_HOME` (see `launchConfigured`), then assert what was
/// applied through the DEBUG state dump (`/tmp/xtty-state-dump.json`): font, theme,
/// option-as-meta, and scrollback depth. Theme/font/option-as-meta aren't visible
/// in the grid text and scrollback depth needs the engine, so the state dump — not
/// the grid dump — is the channel here. Without the DEBUG hook the substring/state
/// assertions are skipped and the screenshot remains the record.
final class XttyConfigUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // 6.2a: a config file is read at launch and applied to the live terminal.
    func testConfigFileIsAppliedAtLaunch() throws {
        let app = launchConfigured(config: """
        # xtty UI-test config
        font-family = Menlo
        font-size = 16
        theme = light
        scrollback = 7000
        option-as-meta = false
        """)
        XCTAssertTrue(app.terminal.waitForExistence(timeout: 10),
                      "terminal view never appeared")
        GridDumpReader.waitForNonEmpty(timeout: 10)

        guard let state = StateDumpReader.waitForState(timeout: 10) else {
            // No DEBUG hook (e.g. Release): keep the screenshot as the record.
            attachScreenshot("config-applied-no-hook")
            XCTAssertTrue(app.mainWindow.exists)
            app.terminate()
            return
        }
        attachScreenshot("config-applied-light-menlo")
        StateDumpReader.attach(self, name: "config-state")

        XCTAssertEqual(state["theme"] as? String, "light",
                       "theme from config not applied")
        XCTAssertEqual(state["optionAsMeta"] as? Bool, false,
                       "option-as-meta from config not applied")
        XCTAssertEqual((state["scrollbackCap"] as? NSNumber)?.intValue, 7000,
                       "scrollback cap from config not applied")
        XCTAssertEqual((state["fontSize"] as? NSNumber)?.doubleValue ?? 0, 16, accuracy: 0.5,
                       "font size from config not applied")
        let family = (state["fontFamily"] as? String) ?? ""
        XCTAssertTrue(family.localizedCaseInsensitiveContains("Menlo"),
                      "font family '\(family)' should be Menlo")

        app.terminate()
    }

    // 6.2b: scrollback is bounded under heavy output (product value M1). We shrink
    //  the cap via `-UITestScrollback` so a modest flood overflows it, then assert
    //  the scrollback depth saturates at exactly the cap (and total retained lines
    //  stay within cap + visible rows).
    func testScrollbackIsBoundedUnderHeavyOutput() throws {
        let cap = 200
        // The file asks for a large cap; the launch override (cap) must win.
        let app = launchConfigured(config: "scrollback = 50000\n", scrollbackOverride: cap)
        XCTAssertTrue(app.terminal.waitForExistence(timeout: 10),
                      "terminal view never appeared")
        GridDumpReader.waitForNonEmpty(timeout: 10)
        app.activate()

        // Flood far more than the cap on the NORMAL buffer (seq/printf, no pager),
        // ending in a unique sentinel so we know output drained + re-pinned bottom.
        let sentinel = "FLOODDONE\(Int.random(in: 100000...999999))"
        app.typeText("seq 1 5000; printf '%s\\n' \(sentinel)")
        app.typeKey(.enter, modifierFlags: [])
        XCTAssertTrue(GridDumpReader.waitForContains(sentinel, timeout: 30),
                      "flood never finished (sentinel missing)")

        guard let state = StateDumpReader.waitForState(timeout: 10, where: {
            ($0["scrollbackDepth"] as? NSNumber)?.intValue ?? 0 >= cap
        }) ?? StateDumpReader.waitForState(timeout: 5) else {
            attachScreenshot("scrollback-no-hook")
            XCTAssertTrue(app.mainWindow.exists)
            app.terminate()
            return
        }
        StateDumpReader.attach(self, name: "scrollback-state")
        attachScreenshot("scrollback-after-flood")

        XCTAssertEqual(state["isAlt"] as? Bool, false,
                       "scrollback bound only meaningful on the normal buffer")
        let rows = (state["rows"] as? NSNumber)?.intValue ?? 0
        let depth = (state["scrollbackDepth"] as? NSNumber)?.intValue ?? -1
        let bufferLines = (state["bufferLines"] as? NSNumber)?.intValue ?? -1

        XCTAssertLessThanOrEqual(depth, cap,
                                 "scrollback depth (\(depth)) must be bounded by the cap (\(cap))")
        XCTAssertEqual(depth, cap,
                       "after flooding >> cap, depth should saturate at the cap")
        XCTAssertLessThanOrEqual(bufferLines, cap + rows,
                                 "total retained lines (\(bufferLines)) must stay within cap + rows (\(cap + rows))")

        app.terminate()
    }
}
