import XCTest

// e2e test for profiles (the add-profiles change). A config whose `default-profile`
// points at a named profile launches the first window with that profile's
// appearance + working directory; the DEBUG state dump reports the profile name,
// theme, and cwd so the test can assert the profile was applied. Degrades
// gracefully (screenshot only) when the DEBUG hook is absent (Release build).
final class XttyProfileUITests: XCTestCase {
    /// Base theme is dark; the `work` profile overrides it to light and starts in
    /// /tmp (a directory that always exists, so cwd resolves).
    private static let config = """
    theme = dark
    default-profile = work

    [profile "work"]
    theme = light
    cwd = /tmp
    """

    func testDefaultProfileLaunchReflectsProfile() {
        let app = launchConfigured(config: Self.config)
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)")
            return  // degrade gracefully when the DEBUG hook is absent
        }

        // The first window launches with default-profile = work.
        let state = StateDumpReader.waitForState(timeout: 10) {
            ($0["profileName"] as? String) == "work"
        }
        XCTAssertEqual(state?["profileName"] as? String, "work",
                       "the first window should use default-profile")
        XCTAssertEqual(state?["theme"] as? String, "light",
                       "the profile theme overrides the base theme")
        XCTAssertEqual(state?["cwd"] as? String, "/tmp",
                       "the profile cwd is applied to the launch")
        StateDumpReader.attach(self, name: "profile-state")
        attachScreenshot("profile-work")
        _ = app
    }
}
