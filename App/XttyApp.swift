import SwiftUI
import AppKit
import XttyCore

/// xtty — native macOS terminal emulator.
///
/// The window is owned by AppKit (`TerminalWindowController`), not a SwiftUI
/// `WindowGroup`: SwiftTerm's terminal view renders black inside SwiftUI's
/// `NSViewRepresentable` host on macOS 26 (it draws into a hand-managed `CALayer`
/// SwiftUI doesn't composite). A plain `NSWindow` composites it correctly. See
/// `TerminalWindowController` for the full rationale.
///
/// SwiftUI still owns the app lifecycle. All engine access goes through `XttyCore`
/// (now: the pane model + session registry).
@main
struct XttyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // No `WindowGroup`: the terminal window is created by `AppDelegate` in
        // AppKit. `Settings` is an inert scene that satisfies the `App` protocol.
        Settings { EmptyView() }
    }
}

/// Creates and owns the terminal window(s), the shared session registry, and the
/// app-level config resolved once at launch.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// The view-free model of all live panes across windows (P5/agents enumerate it).
    private let registry = SessionRegistry()
    private var windowControllers: [TerminalWindowController] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = AppDelegate.loadConfig()

        let controller = TerminalWindowController(config: config, registry: registry)
        windowControllers.append(controller)

        // Install xtty's AppKit main menu (Find/font ride the responder chain).
        NSApp.mainMenu = XttyMainMenu.build()
        NSApp.activate(ignoringOtherApps: true)

        #if DEBUG
        // XCUITest harness: mirror the focused pane's engine grid to a temp file
        // the test runner reads. Never active in normal runs.
        if ProcessInfo.processInfo.arguments.contains("-UITestGridDump") {
            controller.startGridDumpForUITests()
        }
        #endif
    }

    // Quit when the last window closes (a native tab is a window, so this still
    // yields correct quit-on-last semantics once tabbing lands in layer 3).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // Terminate every child shell on quit so no orphan process is leaked.
    func applicationWillTerminate(_ notification: Notification) {
        for controller in windowControllers { controller.terminate() }
    }

    /// Load + resolve the user config once at launch (P2 read-once policy).
    private static func loadConfig() -> XttyConfig {
        let loaded = XttyConfigLoader.load(warn: { NSLog("[xtty] config: %@", $0) })
        #if DEBUG
        return applyUITestOverrides(to: loaded)
        #else
        return loaded
        #endif
    }

    #if DEBUG
    /// XCUITest determinism: `-UITestScrollback <n>` shrinks the scrollback cap so
    /// the bounded-scrollback flood test runs fast with an exact saturation point.
    private static func applyUITestOverrides(to config: XttyConfig) -> XttyConfig {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-UITestScrollback"),
              i + 1 < args.count, let n = Int(args[i + 1]), n >= 0 else {
            return config
        }
        var overridden = config
        overridden.scrollback = n
        return overridden
    }
    #endif
}
