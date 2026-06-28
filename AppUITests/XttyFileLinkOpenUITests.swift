import XCTest

// e2e for file-link click-to-open (add-file-link-open, P4b-1). A real Cmd-click
// over a detected link in the custom-drawn view can't be reliably synthesized, so
// the test writes a synthetic link string to a temp file whose path it passes via
// the XTTY_TEST_LINK_PATH launch env; the app's DEBUG dump timer polls it and
// routes it through the REAL app pipeline + the focused pane's live cwd, recording
// the resolved action in the state dump. No editor is launched (the DEBUG path
// resolves + records only). Assertions are made against the state dump, not the AX
// tree, and degrade gracefully (screenshot) when the hook/capture is absent.
final class XttyFileLinkOpenUITests: XCTestCase {

    // The sandboxed runner can't write /tmp, so it writes the link to its own
    // (writable) temp dir; the app reads this path via the XTTY_TEST_LINK_PATH env.
    private let linkInputPath = (NSTemporaryDirectory() as NSString)
        .appendingPathComponent("xtty-test-link.txt")

    private func type(_ command: String, into app: XCUIApplication) {
        app.typeText(command)
        app.typeKey(.enter, modifierFlags: [])
    }

    private func launch() -> XCUIApplication {
        launchConfigured(config: "", extraEnv: ["XTTY_TEST_LINK_PATH": linkInputPath])
    }

    /// Write a synthetic link for the app's DEBUG dump timer to pick up and route
    /// through the real pipeline (it consumes the file and records the action).
    private func routeTestLink(_ link: String) {
        try? link.write(toFile: linkInputPath, atomically: true, encoding: .utf8)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: linkInputPath)
        super.tearDown()
    }

    /// A relative file link resolves against the focused pane's live cwd (OSC 7).
    func testRelativeFileLinkResolvesAgainstCwd() {
        let app = launch()
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)")
            return
        }
        _ = GridDumpReader.waitForNonEmpty(timeout: 5)

        // cd into a unique, non-symlinked directory under HOME so OSC 7 reports it
        // verbatim and the resolved path is an exact join (no /tmp→/private rewrite).
        let cwd = (NSHomeDirectory() as NSString).appendingPathComponent("xtty-linktest-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: cwd, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(atPath: cwd) }

        type("cd \(cwd)", into: app)
        guard StateDumpReader.waitForState(timeout: 8, where: {
            ($0["currentDirectory"] as? String) == cwd
        }) != nil else {
            attachScreenshot("semantic-capture-inactive (host zsh config?)")
            return
        }

        routeTestLink("notes.txt:12")
        let state = StateDumpReader.waitForState(timeout: 5) {
            (($0["lastLinkOpen"] as? [String: Any])?["action"] as? String) == "opened"
        }
        let link = state?["lastLinkOpen"] as? [String: Any]
        XCTAssertEqual(link?["kind"] as? String, "file")
        XCTAssertEqual(link?["path"] as? String, "\(cwd)/notes.txt",
                       "the relative path should resolve against the live cwd")
        XCTAssertEqual((link?["line"] as? NSNumber)?.intValue, 12)
        StateDumpReader.attach(self, name: "file-link-open")
    }

    /// A non-permitted scheme is blocked (the D7 guard) — no cwd/capture needed.
    func testNonPermittedSchemeIsBlocked() {
        let app = launch()
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)")
            return
        }

        routeTestLink("x-launch://do-something")
        let state = StateDumpReader.waitForState(timeout: 5) {
            (($0["lastLinkOpen"] as? [String: Any])?["action"] as? String) == "blocked"
        }
        let link = state?["lastLinkOpen"] as? [String: Any]
        XCTAssertEqual(link?["action"] as? String, "blocked",
                       "a custom scheme should be blocked by the guard")
        XCTAssertEqual(link?["scheme"] as? String, "x-launch")
        attachScreenshot("blocked-scheme")
    }
}
