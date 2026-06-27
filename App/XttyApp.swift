import SwiftUI
import AppKit

/// xtty — native macOS terminal emulator.
///
/// P1: the app launches a live terminal session running the user's login shell.
///
/// The window is owned by AppKit (`TerminalWindowController`), not a SwiftUI
/// `WindowGroup`: SwiftTerm's terminal view renders black when hosted inside
/// SwiftUI's `NSViewRepresentable` on macOS 26 (it draws into a hand-managed
/// `CALayer` that SwiftUI's host does not composite — for both the CoreGraphics
/// and the Metal render paths). A plain `NSWindow` composites it correctly. See
/// `TerminalWindowController` for the full rationale.
///
/// SwiftUI still owns the app lifecycle (and gives us the standard App/Edit/View/
/// Window/Help menus for free; it can host future chrome — e.g. the P8 progress
/// sidebar — as ordinary SwiftUI content via `NSHostingView`; only SwiftTerm's
/// custom-drawn view must stay in the AppKit hierarchy). All engine access goes
/// through `XttyCore`.
@main
struct XttyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // No `WindowGroup`: the terminal window is created by `AppDelegate` in
        // AppKit. `Settings` is an inert scene that shows no window at launch and
        // satisfies the `App` protocol's scene requirement.
        Settings { EmptyView() }
    }
}

/// Creates and owns the terminal window, and wires app-level lifecycle.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var terminalController: TerminalWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        terminalController = TerminalWindowController()

        // Install xtty's AppKit main menu. SwiftUI's `App` installs a default
        // menu, but we replace it: Find needs an `NSMenuItem` sender routed
        // through the AppKit responder chain (see `XttyMainMenu`). Done after the
        // controller exists so the font-size items target the live delegate.
        NSApp.mainMenu = XttyMainMenu.build(fontActionTarget: self)

        NSApp.activate(ignoringOtherApps: true)

        #if DEBUG
        // XCUITest harness: when launched with `-UITestGridDump`, mirror the
        // headless engine grid to a temp file the test runner reads for
        // deterministic content assertions. Never active in normal runs.
        if ProcessInfo.processInfo.arguments.contains("-UITestGridDump") {
            terminalController?.startGridDumpForUITests()
        }
        #endif
    }

    // Single-window app: quit when the terminal window closes.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // Terminate the child shell on quit so no orphan process is leaked.
    func applicationWillTerminate(_ notification: Notification) {
        terminalController?.terminate()
    }

    // MARK: Font-size menu actions
    //
    // Routed here (not the terminal view) because they adjust the session's font
    // ephemerally; the controller owns the view + the configured base size. These
    // are `target`ed at the delegate by `XttyMainMenu`, so they fire regardless of
    // first responder.

    @MainActor @objc func increaseFontSize(_ sender: Any?) {
        terminalController?.adjustFontSize(by: +1)
    }

    @MainActor @objc func decreaseFontSize(_ sender: Any?) {
        terminalController?.adjustFontSize(by: -1)
    }

    @MainActor @objc func resetFontSize(_ sender: Any?) {
        terminalController?.resetFontSize()
    }
}
