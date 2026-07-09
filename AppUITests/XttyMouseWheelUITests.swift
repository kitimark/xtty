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
    // Down arrow). Magnitude 3 → ~3 whole rows, bounded by whole-cell quantization
    // — NOT a fixed per-gesture cap (smooth-scroll-wheel-momentum D2 removed the
    // `min(cap, whole)` this comment used to describe; see testInjectedFastPrecise-
    // GestureDoesNotLoseDistance for the lossless-carry regression guard).
    private let wheelUp: CGFloat = 3
    private let wheelDown: CGFloat = -3

    // MARK: Momentum/precise injection (smooth-scroll-wheel-momentum D8)

    private let wheelInputPath = (NSTemporaryDirectory() as NSString)
        .appendingPathComponent("xtty-test-wheel.txt")

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: wheelInputPath)
        super.tearDown()
    }

    /// Launch with the synthetic-wheel-injection hook's env var wired, so the app
    /// polls `wheelInputPath` for test-authored wheel-event specs (D8).
    private func launchForInjection() -> XCUIApplication {
        launchConfigured(config: "", extraEnv: ["XTTY_TEST_WHEEL_PATH": wheelInputPath])
    }

    /// Write a synthetic wheel-event spec and wait for the app to consume
    /// (delete) it. Spec = "gesturePhase:momentumPhase:precise:deltaY:shift" —
    /// gesturePhase/momentumPhase ∈ none|began|changed|ended, deltaY a signed
    /// pixel magnitude (positive = up, matching the automation-channel
    /// convention above). File-consumption and the routed `lastWheelRouting`
    /// update happen in the same synchronous app-timer tick (App/XttyApp.swift's
    /// `routePendingTestWheelInjection` runs before `writeUITestDumps()`), so a
    /// `routing()` read immediately after this returns sees that event's outcome.
    @discardableResult
    private func injectWheel(gesturePhase: String = "none", momentumPhase: String = "none",
                             precise: Bool = true, deltaY: Int, shift: Bool = false,
                             timeout: TimeInterval = 5) -> Bool {
        let spec = "\(gesturePhase):\(momentumPhase):\(precise):\(deltaY):\(shift)"
        try? spec.write(toFile: wheelInputPath, atomically: true, encoding: .utf8)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !FileManager.default.fileExists(atPath: wheelInputPath) { return true }
            usleep(80_000)
        }
        return false
    }

    /// Arm active button-event mouse reporting on the alternate screen (BRANCH 1,
    /// `.report`) — the only branch that calls the precise-delta accumulator
    /// (`xttyWheelRowCount`) the momentum/lossless-carry/reset tests exercise;
    /// BRANCH 3 (local scrollback) uses the untouched `calcScrollingVelocity`
    /// instead (design Non-Goals).
    @discardableResult
    private func armMouseReportingOnAltScreen(_ app: XCUIApplication) -> Bool {
        type("printf '\\033[?1002h\\033[?1049h'", into: app)
        return StateDumpReader.waitForState(timeout: 10, where: { ($0["isAlt"] as? Bool) == true }) != nil
    }

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

    // MARK: 3.1 — crisp negative: a real automation-channel gesture carries no momentum

    // Scenario: a real synthetic gesture is recorded as a non-momentum event
    // (smooth-scroll-wheel-momentum). XCUITest's `scroll(byDeltaX:deltaY:)` never
    // carries an inertial-coast phase, so this proves the `momentum` field is
    // wired on the real-gesture path — the `momentum == true` path is covered by
    // the injection tests below, since automation-channel gestures can't produce it.
    func testRealGestureIsRecordedAsNonMomentum() {
        let app = launchConfigured(config: "")
        guard prepared(app) else { return }

        scrollWheel(over: app, delta: wheelUp)
        let r = routing({ ($0["momentum"] as? Bool) == false })
        StateDumpReader.attach(self, name: "wheel-real-gesture-non-momentum")
        XCTAssertEqual(r?["momentum"] as? Bool, false,
                       "a real automation-channel gesture must be recorded as non-momentum "
                       + "(finger-driven) — automation carries no inertial coast")
    }

    // MARK: 3.2–3.4 — synthetic momentum-routing coverage via injection (D8)

    // Scenario: an injected momentum frame is routed, not dropped. Guards D1 (the
    // deletion of the blanket `momentumPhase != [] { return }` guard) — before the
    // fix, this frame would silently vanish before ever reaching a branch, so
    // `lastWheelRouting` would still show the PRIOR event (or nil), never `momentum: true`.
    func testInjectedMomentumFrameIsRoutedNotDropped() {
        let app = launchForInjection()
        guard prepared(app) else { return }
        guard armMouseReportingOnAltScreen(app) else {
            attachScreenshot("alt-screen-not-active")
            XCTFail("terminal never entered the alternate screen / armed mouse reporting")
            return
        }

        XCTAssertTrue(injectWheel(momentumPhase: "changed", precise: true, deltaY: 5),
                      "app never consumed the injected wheel-event spec")
        let r = routing({ ($0["momentum"] as? Bool) == true })
        StateDumpReader.attach(self, name: "wheel-momentum-not-dropped")
        XCTAssertEqual(r?["branch"] as? String, "report",
                       "an injected momentum frame under active mouse tracking must route on the "
                       + "report branch, same as a finger-driven frame")
        XCTAssertEqual(r?["momentum"] as? Bool, true,
                       "the routed event must be recorded as a momentum (inertial-coast) frame — "
                       + "not silently dropped")
    }

    // Scenario: an injected momentum frame produces a REAL SGR mouse-report byte
    // sequence the child process receives — not just a `lastWheelRouting`
    // bookkeeping update. This automates the byte-level portion of the manual
    // physical-trackpad verify's step 1 technique (packer/README.md task 4.4):
    // arm SGR mouse tracking + `cat -v` (which echoes ESC as literal `^[` text
    // instead of xtty's own VT parser silently consuming the unrecognized
    // sequence), then assert the wheel button 64 (up) press-only SGR sequence
    // appears in the visible grid. It does NOT and cannot automate whether macOS
    // actually DELIVERS a real inertial-coast frame during a physical flick, at
    // what rate, or whether the child stays responsive under sustained coast —
    // those remain the manual verify's job (D8's documented limit; the injection
    // hook proves xtty's logic given a momentum event, never that the OS
    // produces one). This closes the adjacent, automatable gap instead: given a
    // momentum event (however sourced), do the correct bytes really leave xtty
    // and reach the child, not just get recorded as "reported" internally.
    func testInjectedMomentumFrameProducesRealSGRMouseReportBytes() {
        let app = launchForInjection()
        guard prepared(app) else { return }

        type("printf '\\033[?1002h\\033[?1006h'; cat -v", into: app)
        _ = StateDumpReader.waitForState(timeout: 3)  // let mouse mode settle

        // A large delta guarantees at least one whole-cell report regardless of
        // font/cell height (mirrors the lossless-carry test's margin reasoning).
        XCTAssertTrue(injectWheel(momentumPhase: "changed", precise: true, deltaY: 500),
                      "app never consumed the injected wheel-event spec")

        // cat -v renders ESC (0x1B) as literal `^[`, so a real SGR wheel-up
        // report (`ESC[<64;col;row` + `M`, press-only — no matching release)
        // appears as plain visible text instead of being parsed as a control
        // sequence xtty's own engine would otherwise silently consume.
        XCTAssertTrue(GridDumpReader.waitForContains("^[[<64;", timeout: 5, ignoringLineWraps: true),
                      "an injected momentum frame's mouse report never reached the child process "
                      + "as a real SGR byte sequence (cat -v never echoed ^[[<64;…M)")
        attachGridDump("wheel-momentum-sgr-bytes")
    }

    // Scenario: an injected fast precise gesture does not lose scroll distance.
    // Guards D2 (the `xttyWheelRowCount` rewrite from `remainder -= whole; return
    // min(5, whole)` — discarding overflow — to carrying the full remainder and
    // emitting every accumulated whole row).
    func testInjectedFastPreciseGestureDoesNotLoseDistance() {
        let app = launchForInjection()
        guard prepared(app) else { return }
        guard armMouseReportingOnAltScreen(app) else {
            attachScreenshot("alt-screen-not-active")
            XCTFail("terminal never entered the alternate screen / armed mouse reporting")
            return
        }

        // 10,000px of accumulated travel in one gesture: any real font's cell
        // height is well under 200px, so this spans dozens of whole cells — far
        // beyond the old fixed cap of 5.
        XCTAssertTrue(injectWheel(gesturePhase: "began", precise: true, deltaY: 10_000),
                      "app never consumed the injected wheel-event spec")
        let r = routing({ (($0["count"] as? NSNumber)?.intValue ?? 0) > 5 })
        StateDumpReader.attach(self, name: "wheel-lossless-carry")
        XCTAssertEqual(r?["branch"] as? String, "report")
        let count = (r?["count"] as? NSNumber)?.intValue ?? -1
        XCTAssertGreaterThan(count, 5,
                             "a fast precise gesture accumulating 10,000px must emit more than the "
                             + "old fixed cap of 5 rows (got \(count)) — distance must not be discarded")
    }

    // Scenario: the accumulated remainder resets between gestures. Guards D3 (the
    // `.began`-phase remainder reset). Self-calibrates the (font-dependent) cell
    // height from a throwaway large gesture, then sends two ~0.6-cell `.began`
    // gestures: each alone must stay under one whole cell (count 0), but if the
    // reset regressed, the second would inherit the first's leftover and the two
    // ~0.6-cell fractions would sum past a whole cell (a phantom count ≥ 1).
    //
    // `routing()` with no predicate returns whatever `lastWheelRouting` currently
    // holds — it does NOT wait for a value distinct from the last one this test
    // already observed. Under the fast-follow calibration → first → second
    // sequence this can win the race against the app's dump-write (measured on a
    // graphics-tier VM run: the "first" read returned the calibration's own
    // stale, much-larger count). Each read below therefore polls a predicate that
    // ONLY the fresh event can satisfy — "first"'s count must differ from the
    // calibration's (which is orders of magnitude larger), and "second" flips
    // scroll direction from "first" (same magnitude, opposite sign) so its
    // `direction` field alone disambiguates it even though both correctly report
    // `count == 0` and are otherwise identical.
    func testAccumulatedRemainderResetsBetweenGestures() {
        let app = launchForInjection()
        guard prepared(app) else { return }
        guard armMouseReportingOnAltScreen(app) else {
            attachScreenshot("alt-screen-not-active")
            XCTFail("terminal never entered the alternate screen / armed mouse reporting")
            return
        }

        let calibrationDelta = 100_000
        XCTAssertTrue(injectWheel(gesturePhase: "began", precise: true, deltaY: calibrationDelta),
                      "app never consumed the calibration wheel-event spec")
        guard let calRouting = routing({ (($0["count"] as? NSNumber)?.intValue ?? 0) > 0 }),
              let calCount = (calRouting["count"] as? NSNumber)?.intValue, calCount > 0 else {
            XCTFail("calibration gesture never produced a positive row count — cannot derive cell height")
            return
        }
        let cellHeight = Double(calibrationDelta) / Double(calCount)
        let perGesture = Int((cellHeight * 0.6).rounded(.up))

        // "first" scrolls UP (positive deltaY, matching calibration's sign) — its
        // count must differ from the calibration's to be trusted as fresh.
        XCTAssertTrue(injectWheel(gesturePhase: "began", precise: true, deltaY: perGesture),
                      "app never consumed the first wheel-event spec")
        let first = routing({ (($0["count"] as? NSNumber)?.intValue ?? -1) != calCount })
        let firstCount = (first?["count"] as? NSNumber)?.intValue ?? -1
        XCTAssertEqual(firstCount, 0,
                       "setup check: a single ~0.6-cell precise gesture must not itself emit a "
                       + "whole row (got \(firstCount)) — recalibrate perGesture")

        // "second" scrolls DOWN (negative deltaY, same magnitude) — a fresh
        // "direction": "down" can only come from this event, never a stale
        // repeat of "first" (which was "up").
        XCTAssertTrue(injectWheel(gesturePhase: "began", precise: true, deltaY: -perGesture),
                      "app never consumed the second wheel-event spec")
        let second = routing({ ($0["direction"] as? String) == "down" })
        StateDumpReader.attach(self, name: "wheel-began-reset")
        XCTAssertEqual(second?["direction"] as? String, "down",
                       "the second gesture's routing never arrived (still reading a stale 'up' "
                       + "dict) — synchronization failed, not the D3 assertion itself")
        let secondCount = (second?["count"] as? NSNumber)?.intValue ?? -1
        XCTAssertEqual(secondCount, 0,
                       "a new .began gesture must not inherit the previous gesture's leftover "
                       + "sub-cell remainder as a phantom extra row (got \(secondCount))")
    }
}
