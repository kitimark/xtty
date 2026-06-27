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
final class AppDelegate: NSObject, NSApplicationDelegate, WindowCoordinator {
    /// The view-free model of all live panes across windows (P5/agents enumerate it).
    private let registry = SessionRegistry()
    private var windowControllers: [TerminalWindowController] = []
    /// Resolved once at launch; reused when opening new windows/tabs.
    private var config = XttyConfig.default
    #if DEBUG
    private var dumpTimer: Timer?
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        let (config, keybindings) = AppDelegate.loadConfigAndKeybindings()
        self.config = config

        let controller = TerminalWindowController(config: config, registry: registry)
        controller.coordinator = self
        windowControllers.append(controller)

        // Install xtty's AppKit main menu with key equivalents from config (Find/
        // font/split/focus ride the responder chain to the focused pane).
        NSApp.mainMenu = XttyMainMenu.build(keybindings: keybindings)
        NSApp.activate(ignoringOtherApps: true)

        #if DEBUG
        // XCUITest harness: one app-level timer mirrors the KEY window's focused-
        // pane grid + inventory to temp files (handles multiple tabs/windows
        // without controllers fighting over the path). Never active in normal runs.
        if ProcessInfo.processInfo.arguments.contains("-UITestGridDump") {
            startUITestDump()
        }
        #endif
    }

    #if DEBUG
    private func startUITestDump() {
        dumpTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let key = NSApp.keyWindow
                let controller = self.windowControllers.first { $0.window === key }
                    ?? self.windowControllers.last
                controller?.writeUITestDumps()
            }
        }
    }
    #endif

    // Quit when the last window closes (a native tab is a window, so this still
    // yields correct quit-on-last semantics once tabbing lands in layer 3).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // Terminate every child shell on quit so no orphan process is leaked.
    func applicationWillTerminate(_ notification: Notification) {
        for controller in windowControllers { controller.terminate() }
    }

    // MARK: WindowCoordinator

    @discardableResult
    func openNewWindow() -> TerminalWindowController {
        let controller = TerminalWindowController(config: config, registry: registry)
        controller.coordinator = self
        windowControllers.append(controller)
        return controller  // the app-level dump timer covers every window
    }

    func openNewTab(relativeTo controller: TerminalWindowController) {
        let newController = openNewWindow()
        // Group it as a native tab of the originating window.
        controller.window.addTabbedWindow(newController.window, ordered: .above)
        newController.window.makeKeyAndOrderFront(nil)
    }

    func windowControllerDidClose(_ controller: TerminalWindowController) {
        // Defer releasing the controller (and thus its window/views) to the next
        // runloop, so they outlive the in-progress close display cycle.
        DispatchQueue.main.async { [weak self] in
            self?.windowControllers.removeAll { $0 === controller }
        }
    }

    /// The native tab bar's "+" button (and the default New-Tab path) route here.
    @objc func newWindowForTab(_ sender: Any?) {
        if let key = NSApp.keyWindow,
           let controller = windowControllers.first(where: { $0.window == key }) {
            openNewTab(relativeTo: controller)
        } else {
            openNewWindow()
        }
    }

    /// Load + resolve the user config and keybindings once at launch from a single
    /// file read (P2 read-once policy). Keybindings live in the
    /// `terminal-keybindings` capability; config in `terminal-configuration`.
    private static func loadConfigAndKeybindings() -> (XttyConfig, Keybindings) {
        let environment = ProcessInfo.processInfo.environment
        let path = XttyConfigLoader.configPath(environment: environment, homeDirectory: NSHomeDirectory())
        let text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        let pairs = XttyConfigLoader.parse(text)
        let warn: (String) -> Void = { NSLog("[xtty] config: %@", $0) }

        var config = XttyConfigLoader.resolve(from: pairs, warn: warn)
        let keybindings = KeybindResolver.resolve(from: pairs, warn: warn)
        #if DEBUG
        config = applyUITestOverrides(to: config)
        #endif
        return (config, keybindings)
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
