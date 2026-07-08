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
        // The state dump backs the menu canary; reset it too so a stale dump
        // from a prior app instance can never vouch for this launch's menu.
        StateDumpReader.reset()
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

    // 2. Multi-line paste matches the shell's bracketing capability
    //    (split-shell-dependent-testplan). The SAME paste, forwarded faithfully by
    //    xtty, produces a shell-determined outcome — and both outcomes are correct
    //    xtty behavior (layer-2 forwarding fidelity, design D2):
    //      • bracketed-paste ON  (zsh, bash ≥ 4.4): both lines STAGED, nothing runs.
    //      • bracketed-paste OFF (macOS bash 3.2):   readline treats each ⏎ as
    //        accept-line, so the newline-terminated first line EXECUTES while the
    //        unterminated tail line stays staged.
    //    The branch predicate is the *observed* bracketed-paste mode from the DEBUG
    //    state dump (design D5), sampled after the computed-marker readiness gate —
    //    never the shell binary/version.
    func testMultiLinePasteMatchesShellBracketing() throws {
        app.activate()
        // Readiness (D5): the shell has executed a command and is back at its
        // prompt, so bracketed paste (if the shell supports it) is enabled and the
        // observed capability predicate is stable — never sampled before the prompt.
        if GridDumpReader.isAvailable {
            XCTAssertTrue(waitForShellReady(app),
                          "shell never reached readiness before sampling bracketed-paste mode")
        }

        let tag = Int.random(in: 1000...9999)
        let lineA = "alpha\(tag)"
        let lineB = "beta\(tag)"

        let pb = NSPasteboard.general
        pb.clearContents()
        // NB: no trailing newline — so on a non-bracketed shell only the first
        // (newline-terminated) line accepts; the tail stays staged.
        pb.setString("\(lineA)\n\(lineB)", forType: .string)

        // Cmd+V dispatches via the Edit▸Paste menu item — refuse to drive it
        // against a clobbered menu (fatal canary; Release builds skip with the
        // rest of the dump-gated assertions).
        if GridDumpReader.isAvailable { requireXttyMainMenu(in: app) }
        app.typeKey("v", modifierFlags: .command) // Cmd+V; DO NOT press Return

        attachScreenshot("paste-staged-before-return")
        attachGridDump("paste-grid")

        if GridDumpReader.isAvailable {
            // The observed capability predicate (D5): whether the shell enabled
            // bracketed paste at its prompt — read from the state dump AFTER
            // readiness, never inferred from the shell binary/version.
            let bracketed = (StateDumpReader.read()?["bracketedPasteMode"] as? Bool) ?? false
            StateDumpReader.attach(self, name: "paste-bracketed-mode-\(bracketed)")

            // Both arms: the first pasted line lands in the grid. Wrap-tolerant per
            // harden-paste-wrap-assertion — behind a wide prompt (the zsh VM rig's
            // 70-col prompt pushes the 9-char line past the 78-col wrap) a pasted
            // line soft-wraps across physical rows, which the dump joins with "\n".
            // The line still reached the focused pane's grid; a genuinely absent
            // line still fails.
            XCTAssertTrue(GridDumpReader.waitForContains(lineA, timeout: 5, ignoringLineWraps: true),
                          "first pasted line missing from grid")

            if bracketed {
                // zsh / bracketed-ON arm: BOTH lines staged, nothing executed — the
                // staged-not-executed guarantee (kept wrap-tolerant per harden-paste).
                XCTAssertTrue(GridDumpReader.waitForContains(lineB, timeout: 5, ignoringLineWraps: true),
                              "second pasted line missing (bracketed paste should stage both lines)")
                let grid = GridDumpReader.read() ?? ""
                XCTAssertFalse(grid.lowercased().contains("command not found"),
                               "bracketed paste should stage both lines, not execute them")
            } else {
                // bash 3.2 / bracketed-OFF arm: the newline-terminated first line
                // EXECUTES (`alpha<tag>: command not found`) — xtty's faithful
                // forwarding, correct for that shell (design D2). The unterminated
                // tail line stays staged at the next prompt.
                XCTAssertTrue(GridDumpReader.waitForContains("command not found", timeout: 5),
                              "the newline-terminated first line should have executed on a non-bracketed shell")
                XCTAssertTrue(GridDumpReader.waitForContains(lineB, timeout: 5, ignoringLineWraps: true),
                              "the unterminated tail line should remain staged at the prompt")
                // Exactly one execution: the tail has no trailing ⏎, so it must NOT
                // have produced its own `command not found`.
                let grid = (GridDumpReader.read() ?? "").lowercased()
                let executions = grid.components(separatedBy: "command not found").count - 1
                XCTAssertEqual(executions, 1,
                               "only the newline-terminated first line should execute; the tail stays staged")
            }
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

        // Cmd+F dispatches via Edit▸Find — fatal canary first (see paste test).
        if GridDumpReader.isAvailable { requireXttyMainMenu(in: app) }
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
            // Wrap-tolerant (mirrors :53): behind a long shell prompt — the
            // hosted-runner findbar-marker-wrap case — the marker soft-wraps
            // across physical rows, which the dump joins with "\n". Focus
            // restoration is still what's asserted: the marker reached the
            // terminal grid, it just wrapped; a genuinely absent marker (routed
            // to the search field) still fails. See ci-runner-prompt-width-forensics.md.
            XCTAssertTrue(GridDumpReader.waitForContains(marker, timeout: 5, ignoringLineWraps: true),
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
        // Unlike the multi-line paste test, this payload is a SINGLE line with an
        // explicit Return, so it executes identically on both shells — bracketed or
        // not (no accept-line divergence to branch on, so no bracketedPasteMode
        // arm). The one concern it shares with the paste test is soft-wrap: behind
        // a wide prompt the pasted+echoed line wraps across dump rows, so the
        // emoji/CJK assertions are wrap-tolerant per harden-paste-wrap-assertion.
        let i18n = "echo ROCKET\(tag) 🚀 日本語 ✅"
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(i18n, forType: .string)
        // The paste rides Edit▸Paste — fatal canary first (see paste test).
        if GridDumpReader.isAvailable { requireXttyMainMenu(in: app) }
        app.typeKey("v", modifierFlags: .command)
        app.typeKey(.enter, modifierFlags: [])

        attachScreenshot("i18n-truecolor-emoji-wide")
        attachGridDump("i18n-grid")

        if GridDumpReader.isAvailable {
            XCTAssertTrue(GridDumpReader.waitForContains("🚀", timeout: 5, ignoringLineWraps: true),
                          "non-BMP emoji (🚀) missing from grid — characterProvider not applied?")
            XCTAssertTrue(GridDumpReader.waitForContains("日本語", timeout: 5, ignoringLineWraps: true),
                          "wide CJK garbled/missing — skipNullCellsFollowingWide not applied?")
            XCTAssertTrue(GridDumpReader.waitForContains("✅", timeout: 5, ignoringLineWraps: true),
                          "BMP emoji (✅) missing from grid")
        } else {
            XCTAssertTrue(app.mainWindow.exists)
        }
    }

    // 7. Deterministic soft-wrap regression guard (harden-findbar-wrap-assertion).
    //    Types a single contiguous marker far wider than the focused pane so it is
    //    GUARANTEED to soft-wrap across ≥2 physical rows in the grid dump —
    //    reproducing the hosted-runner findbar-marker-wrap phenomenon on bare metal
    //    in `make test`, independent of the ambient hostname/prompt width. This
    //    keeps the wrap class from silently respawning. Self-validating: the
    //    wrap-tolerant match MUST succeed while a STRICT physical-row match of the
    //    same whole token MUST fail (a "\n" row boundary split it) — so the guard
    //    can never pass without a genuine wrap. If the pane is wider than the marker
    //    it fails loudly (widen the marker). See ci-runner-prompt-width-forensics.md.
    func testSoftWrapGuardIsWrapTolerant() throws {
        try XCTSkipUnless(GridDumpReader.isAvailable,
                          "grid dump hook required (DEBUG build launched with -UITestGridDump)")
        app.activate()
        XCTAssertTrue(app.mainWindow.waitForExistence(timeout: 5))

        // Unique prefix (no collisions) + wide alphanumeric padding: the whole
        // contiguous token is far wider than any reasonable default pane, so it
        // must wrap. No spaces/metacharacters, so the shell stages it verbatim.
        let marker = "WRAPGUARD\(Int.random(in: 100000...999999))"
            + String(repeating: "Z", count: 150)
        app.typeText(marker)
        attachGridDump("softwrap-guard-grid")

        // First confirm the marker reached the grid at all, recovering it across
        // the wrap boundary. This also gates the strict check below on the marker
        // actually being rendered, so a false strict match means "wrapped", not
        // "not yet echoed".
        XCTAssertTrue(GridDumpReader.waitForContains(marker, timeout: 5, ignoringLineWraps: true),
                      "wrap-tolerant matcher failed to find the typed marker")
        // Now prove it GENUINELY wrapped: a strict, physical-row match of the whole
        // contiguous token must fail because a "\n" row boundary splits it. If this
        // succeeds the marker did not wrap (pane wider than the marker) — fail loudly.
        let grid = GridDumpReader.read() ?? ""
        XCTAssertFalse(GridDumpReader.gridContains(grid, marker, ignoringLineWraps: false),
                       "marker did not soft-wrap (pane wider than the marker) — widen the marker")

        app.typeKey("u", modifierFlags: .control) // clear staged input
    }
}
