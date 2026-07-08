import XCTest

// e2e for mouse-wheel routing (fix-scroll-wheel-mouse-reporting). SwiftTerm's
// scrollWheel previously moved only local scrollback, so it swallowed the wheel
// for full-screen mouse-tracking apps (htop/vim/tmux/fzf) and no-op'd on the
// alternate screen (no scrollback to move). The fix routes the wheel through the
// priority-ordered 3-way branch: mouse-report (highest) → alt-screen cursor keys
// → local scrollback, with a Shift-bypass. These tests assert *which branch* a
// real wheel gesture takes via the DEBUG state dump's `lastWheelRouting` field,
// on the custom-drawn, accessibility-opaque view.
//
// The gesture uses XCTest's own element-targeted scroll synthesis. Plain wheels
// call `scroll(byDeltaX:deltaY:)` directly; Shift+wheel wraps that same call in
// `XCUIElement.perform(withKeyModifiers:)`, so the scroll is still targeted by
// XCTest's automation channel but arrives at AppKit with the Shift modifier.
// The terminal state (mouse mode / alternate screen) is armed with `printf`
// escape sequences, which the engine parses regardless of login shell — so this
// suite is shell-independent (no OSC 133 dependency) and asserts on both goldens.
//
// Task 3.1's fidelity precheck runs first: it proves the synthetic generator
// reaches scrollWheel and moves scrollback deterministically & monotonically,
// taking only the local-scrollback branch (a stray click would surface as a
// report/selection), before any routing assertion is trusted.
final class XttyMouseWheelUITests: XCTestCase {

    // Calibrated against a local run (task 4.1): XCUITest's `scroll(byDeltaX:
    // deltaY:)` with a POSITIVE deltaY delivers a wheel-UP gesture (NSEvent.deltaY
    // > 0 → button 64 / Up arrow); a NEGATIVE deltaY is wheel-DOWN (button 65 /
    // Down arrow). Magnitude 3 → ~3 whole rows (bounded, capped at 5 by the fix).
    private let wheelUp: CGFloat = 3
    private let wheelDown: CGFloat = -3

    // MARK: Helpers

    private func type(_ command: String, into app: XCUIApplication) {
        app.typeText(command)
        app.typeKey(.enter, modifierFlags: [])
    }

    /// Common launch preamble: dump hooks live + shell has executed a command
    /// (rc files sourced, back at its prompt). Returns false on a Release build
    /// (no dump) so the test degrades to screenshot-only, matching the suite.
    @discardableResult
    private func prepared(_ app: XCUIApplication) -> Bool {
        guard StateDumpReader.waitForState(timeout: 10) != nil else {
            attachScreenshot("no-state-dump (Release?)")
            return false
        }
        _ = GridDumpReader.waitForNonEmpty(timeout: 10)
        waitForShellReady(app)
        return true
    }

    /// Drive a real scroll-wheel gesture over the terminal. XCUITest's
    /// `scroll(byDeltaX:deltaY:)` targets the element directly (reliable — it
    /// does not depend on the hardware cursor position). For the Shift-bypass,
    /// `perform(withKeyModifiers:)` pushes Shift into XCTest's automation context
    /// while the same element-targeted scroll is synthesized; the resulting
    /// AppKit `NSEvent` reaches `scrollWheel(with:)` with `.shift` in
    /// `modifierFlags`.
    private func scrollWheel(over app: XCUIApplication, delta: CGFloat, shift: Bool = false) {
        app.activate()
        let term = app.terminal
        _ = term.waitForExistence(timeout: 5)
        guard shift else {
            term.scroll(byDeltaX: 0, deltaY: delta)
            return
        }
        XCUIElement.perform(withKeyModifiers: .shift) {
            term.scroll(byDeltaX: 0, deltaY: delta)
        }
    }

    /// Poll the state dump until `lastWheelRouting` satisfies `matching` (or a
    /// non-null routing exists when no predicate is given), then return the latest
    /// routing dict — the *actual* value, so a mismatch yields a useful message.
    private func routing(_ matching: (([String: Any]) -> Bool)? = nil,
                         timeout: TimeInterval = 8) -> [String: Any]? {
        _ = StateDumpReader.waitForState(timeout: timeout) { st in
            guard let r = st["lastWheelRouting"] as? [String: Any] else { return false }
            return matching?(r) ?? true
        }
        return StateDumpReader.read()?["lastWheelRouting"] as? [String: Any]
    }

    private func depth(_ state: [String: Any]?) -> Int {
        (state?["scrollbackDepth"] as? NSNumber)?.intValue ?? -1
    }

    // MARK: 3.1 — synthetic-event fidelity precheck (runs before routing is trusted)

    func testSyntheticWheelFidelityPrecheck() {
        let app = launchConfigured(config: "")
        guard prepared(app) else { return }

        // Fill the scrollback so an up-scroll has somewhere to go. `seq` is on
        // both goldens; the last line (400) confirms the flood finished drawing.
        type("seq 1 400", into: app)
        XCTAssertTrue(GridDumpReader.waitForContains("400", timeout: 10, ignoringLineWraps: true),
                      "seq 1 400 never finished drawing — cannot precheck scrollback movement")

        // Baseline: viewport pinned at the live bottom (yDisp at its maximum).
        guard let base = StateDumpReader.waitForState(timeout: 5, where: { self.depth($0) > 0 }) else {
            XCTFail("no scrollback accumulated after seq 1 400 (depth stayed 0)")
            return
        }
        var previous = depth(base)

        // N synthetic up-ticks must move the viewport a deterministic, monotonic
        // amount (yDisp strictly decreases as older output scrolls into view), and
        // each tick must take ONLY the local-scrollback branch. A stray click would
        // route through mouse handling (a report/selection, not `scrollback`); a
        // stray keypress or dropped tick would break the strict monotonic decrease.
        for tick in 1...3 {
            scrollWheel(over: app, delta: wheelUp)
            let moved = StateDumpReader.waitForState(timeout: 6, where: { self.depth($0) < previous })
            let now = depth(moved)
            XCTAssertLessThan(now, previous,
                              "tick \(tick): up-scroll must decrease scrollback depth "
                              + "(was \(previous)) — synthetic wheel did not reach scrollWheel")
            let r = moved?["lastWheelRouting"] as? [String: Any]
            XCTAssertEqual(r?["branch"] as? String, "scrollback",
                           "tick \(tick): a no-mouse primary-screen wheel must take the "
                           + "local-scrollback branch (got \(r?["branch"] as? String ?? "nil")) "
                           + "— a stray click would surface as a report/selection")
            previous = now
        }
        StateDumpReader.attach(self, name: "wheel-fidelity-precheck")
    }

    // MARK: 3.2 — the four verification-harness routing scenarios

    // Scenario: wheel over a mouse-tracking alt-screen program reports to it.
    func testWheelOverMouseTrackingAltScreenReportsToProgram() {
        let app = launchConfigured(config: "")
        guard prepared(app) else { return }

        // Enable button-event mouse tracking (?1002) + enter the alternate screen
        // (?1049) — engine-parsed, so this reproduces an htop-style full-screen
        // mouse-tracking app without depending on any program being installed.
        type("printf '\\033[?1002h\\033[?1049h'", into: app)
        guard StateDumpReader.waitForState(timeout: 10, where: { ($0["isAlt"] as? Bool) == true }) != nil else {
            attachScreenshot("alt-screen-not-active")
            XCTFail("terminal never entered the alternate screen (printf ?1049h)")
            return
        }

        scrollWheel(over: app, delta: wheelDown)
        let r = routing({ ($0["branch"] as? String) == "report" })
        StateDumpReader.attach(self, name: "wheel-report-branch")
        XCTAssertEqual(r?["branch"] as? String, "report",
                       "a wheel over a mouse-tracking program must report to it, not move local scrollback")
        XCTAssertEqual(r?["direction"] as? String, "down")
        XCTAssertEqual((r?["button"] as? NSNumber)?.intValue, 65,
                       "scroll-down under mouse reporting → xterm wheel button 65")
    }

    /// Enter the alternate screen (no mouse) with DECCKM in a KNOWN state, then
    /// hold it with a foreground `sleep`. A running command suspends the shell's
    /// line editor, which otherwise re-toggles application-cursor mode at every
    /// prompt (zsh's ZLE emits smkx/rmkx — so a bare zsh prompt is application, a
    /// bare bash prompt is normal). Holding the state via `sleep` makes the
    /// cursor-key form deterministic on both goldens. The arrow keys a later
    /// scroll sends land on the blocked `sleep`'s ignored stdin, perturbing
    /// nothing. Returns once the engine reports the alternate screen.
    @discardableResult
    private func armAltScreenHoldingDECCKM(_ app: XCUIApplication, applicationCursor: Bool) -> Bool {
        let decckm = applicationCursor ? "\\033[?1h" : "\\033[?1l"
        app.typeText("printf '\\033[?1049h\(decckm)'; sleep 30")
        app.typeKey(.enter, modifierFlags: [])
        return StateDumpReader.waitForState(timeout: 10, where: { ($0["isAlt"] as? Bool) == true }) != nil
    }

    // Scenario (normal-cursor arm): a wheel on the alt screen without mouse sends
    // cursor keys; with DECCKM off the emitted form is the normal CSI ESC [ A/B.
    func testWheelOverAltScreenWithoutMouseSendsNormalCursorKeys() {
        let app = launchConfigured(config: "")
        guard prepared(app) else { return }
        guard armAltScreenHoldingDECCKM(app, applicationCursor: false) else {
            attachScreenshot("alt-screen-not-active")
            XCTFail("terminal never entered the alternate screen (printf ?1049h)")
            return
        }

        scrollWheel(over: app, delta: wheelDown)
        let r = routing({ ($0["branch"] as? String) == "cursorKey" })
        StateDumpReader.attach(self, name: "wheel-cursorkey-normal")
        XCTAssertEqual(r?["branch"] as? String, "cursorKey",
                       "a wheel on the alt screen without mouse must send cursor keys")
        XCTAssertEqual(r?["direction"] as? String, "down")
        XCTAssertEqual(r?["keyForm"] as? String, "normal",
                       "DECCKM off (held by sleep) → the normal CSI cursor-key form")
    }

    // Scenario (application-cursor arm): the same wheel with DECCKM on emits the
    // application/SS3 ESC O A/B form (D6 — the handler honors application-cursor).
    func testWheelOverAltScreenWithoutMouseSendsApplicationCursorKeys() {
        let app = launchConfigured(config: "")
        guard prepared(app) else { return }
        guard armAltScreenHoldingDECCKM(app, applicationCursor: true) else {
            attachScreenshot("alt-screen-not-active")
            XCTFail("terminal never entered the alternate screen (printf ?1049h)")
            return
        }

        scrollWheel(over: app, delta: wheelDown)
        let r = routing({ ($0["branch"] as? String) == "cursorKey" })
        StateDumpReader.attach(self, name: "wheel-cursorkey-application")
        XCTAssertEqual(r?["branch"] as? String, "cursorKey",
                       "a wheel on the alt screen without mouse must send cursor keys")
        XCTAssertEqual(r?["direction"] as? String, "down")
        XCTAssertEqual(r?["keyForm"] as? String, "application",
                       "DECCKM on (held by sleep) → the application/SS3 cursor-key form")
    }

    // Scenario: wheel moves local scrollback when no program wants the mouse.
    func testWheelOnPrimaryScreenMovesLocalScrollback() {
        let app = launchConfigured(config: "")
        guard prepared(app) else { return }

        // Primary screen, no mouse reporting (the default at a shell prompt).
        scrollWheel(over: app, delta: wheelUp)
        let r = routing({ ($0["branch"] as? String) == "scrollback" })
        StateDumpReader.attach(self, name: "wheel-scrollback-branch")
        XCTAssertEqual(r?["branch"] as? String, "scrollback",
                       "a no-mouse primary-screen wheel must move the local scrollback viewport")
        XCTAssertEqual(r?["direction"] as? String, "up")
    }

    // Scenario: Shift+wheel over a mouse-tracking program moves local scrollback.
    func testShiftWheelUnderMouseReportingMovesLocalScrollback() {
        let app = launchConfigured(config: "")
        guard prepared(app) else { return }

        // Arm button-event mouse tracking on the primary screen (?1002).
        type("printf '\\033[?1002h'", into: app)
        _ = StateDumpReader.waitForState(timeout: 3)  // let the mode settle

        // A plain (no-Shift) wheel UP confirms mouse reporting is actually active —
        // it must take the report branch (up → button 64). Anchoring UP makes the
        // Shift scroll (DOWN) distinguishable, so a stale/dropped Shift event can't
        // masquerade as success (there is no mouseMode dump field).
        scrollWheel(over: app, delta: wheelUp)
        let armed = routing({ ($0["branch"] as? String) == "report" })
        XCTAssertEqual(armed?["branch"] as? String, "report",
                       "setup check: with ?1002h active a plain wheel must report to the program")

        // Now Shift+wheel DOWN must BYPASS reporting and move local scrollback (D7).
        scrollWheel(over: app, delta: wheelDown, shift: true)
        let bypass = routing({ ($0["branch"] as? String) == "scrollback" })
        StateDumpReader.attach(self, name: "wheel-shift-bypass")
        XCTAssertEqual(bypass?["branch"] as? String, "scrollback",
                       "Shift+wheel under mouse reporting must bypass to local scrollback, not report "
                       + "(actual routing = \(bypass ?? [:]))")
    }
}
