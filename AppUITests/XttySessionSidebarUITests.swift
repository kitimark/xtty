import XCTest

// e2e for the session-progress sidebar (the add-session-sidebar change, P5).
// Drives a real zsh — with xtty's automatic shell-integration injection active —
// and asserts via the DEBUG state dump that the focused pane's derived session
// activity transitions running → succeeded/failed and reports the running command
// while it runs. The sidebar itself is custom SwiftUI chrome with no per-cell
// accessibility text, so the dump (not the AX tree) is the assertion channel.
//
// Like the semantic-capture suite, this depends on the shell-integration hooks
// actually loading (host zsh config must cooperate with the additive hooks), so it
// degrades gracefully (screenshot only) when capture isn't active in the harness
// environment.
final class XttySessionSidebarUITests: XCTestCase {

    private func type(_ command: String, into app: XCUIApplication) {
        app.typeText(command)
        app.typeKey(.enter, modifierFlags: [])
    }

    /// Wait until the DEBUG dump shows semantic capture is live (a non-empty last
    /// action), proving the injected hooks are emitting OSC 133.
    private func waitForCaptureActive(timeout: TimeInterval) -> Bool {
        StateDumpReader.waitForState(timeout: timeout) {
            !(($0["lastSemanticAction"] as? String) ?? "").isEmpty
        } != nil
    }

    func testSidebarStateTracksRunningThenFinished() {
        let app = launchConfigured(config: "")
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)")
            return
        }
        _ = GridDumpReader.waitForNonEmpty(timeout: 5)

        // Warm-up command lets capture prove itself before we assert on activity.
        type("true", into: app)
        guard waitForCaptureActive(timeout: 8) else {
            attachScreenshot("semantic-capture-inactive (host zsh config?)")
            return
        }

        // Running: a long-enough command should surface as activity == running with
        // the command text, caught by the 0.15s dump timer during the sleep window.
        app.typeText("sleep 2")
        app.typeKey(.enter, modifierFlags: [])
        let running = StateDumpReader.waitForState(timeout: 5) {
            ($0["sessionActivity"] as? String) == "running"
        }
        XCTAssertEqual(running?["sessionActivity"] as? String, "running",
                       "the sidebar should show the pane running while `sleep` runs")
        XCTAssertTrue(((running?["runningCommand"] as? String) ?? "").contains("sleep"),
                      "the running command text should be reported; got \(running?["runningCommand"] ?? "nil")")

        // Succeeded once it finishes (the next prompt's D mark closes the block 0).
        let done = StateDumpReader.waitForState(timeout: 10) {
            ($0["sessionActivity"] as? String) == "succeeded"
        }
        XCTAssertEqual(done?["sessionActivity"] as? String, "succeeded",
                       "after `sleep` finishes the session activity should be succeeded")

        // Failed after a failing command.
        type("false", into: app)
        let failed = StateDumpReader.waitForState(timeout: 10) {
            ($0["sessionActivity"] as? String) == "failed"
        }
        XCTAssertEqual(failed?["sessionActivity"] as? String, "failed",
                       "a non-zero exit should make the session activity failed")
        StateDumpReader.attach(self, name: "sidebar-state")
        attachScreenshot("sidebar")
    }
}
