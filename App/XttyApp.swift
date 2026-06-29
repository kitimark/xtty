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
    /// Resolved once at launch (base + named profiles + default selection +
    /// confirm-close); reused when opening new windows/tabs.
    private var configSet = XttyConfigSet(base: XttyProfile(name: nil, config: .default))
    /// The optional quake drop-down terminal + its global hotkey (the
    /// `quick-terminal` capability). Both nil when the feature is off.
    private var quickTerminal: QuickTerminalController?
    private var quickTerminalHotKey: GlobalHotKey?
    #if DEBUG
    private var dumpTimer: Timer?
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        let (configSet, keybindings, quickTerminalSettings) = AppDelegate.loadConfigAndKeybindings()
        self.configSet = configSet

        let controller = TerminalWindowController(
            profile: configSet.defaultProfile, registry: registry, confirmClose: configSet.confirmClose,
            gitReviewLayout: configSet.gitReviewLayout, renderer: configSet.renderer
        )
        controller.coordinator = self
        windowControllers.append(controller)

        // Install xtty's AppKit main menu with key equivalents from config (Find/
        // font/split/focus ride the responder chain to the focused pane) plus the
        // "New Tab with Profile ▸" submenu built from the configured profiles.
        NSApp.mainMenu = XttyMainMenu.build(keybindings: keybindings, profileNames: configSet.profileNames)
        NSApp.activate(ignoringOtherApps: true)

        setUpQuickTerminal(quickTerminalSettings)

        #if DEBUG
        // XCUITest harness: one app-level timer mirrors the KEY window's focused-
        // pane grid + inventory to temp files (handles multiple tabs/windows
        // without controllers fighting over the path). Never active in normal runs.
        if ProcessInfo.processInfo.arguments.contains("-UITestGridDump") {
            startUITestDump()
        }
        // Performance benchmark (P7a): measure latency + memory for the active
        // renderer, write a report, and quit. Let the window settle first.
        if ProcessInfo.processInfo.arguments.contains("-Benchmark") {
            let reportPath = benchmarkReportPath(renderer: configSet.renderer)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak controller] in
                guard let controller else { return }
                BenchmarkRunner.run(controller: controller, renderer: configSet.renderer, reportPath: reportPath)
            }
        }
        #endif
    }

    #if DEBUG
    /// The benchmark report destination: `-BenchmarkReport <path>` when given, else
    /// a renderer-tagged file in the temp dir (the app sandbox is off, so /tmp-like
    /// paths are writable).
    private func benchmarkReportPath(renderer: RendererBackend) -> String {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-BenchmarkReport"), i + 1 < args.count, !args[i + 1].isEmpty {
            return args[i + 1]
        }
        return (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("xtty-bench-\(renderer.rawValue).json")
    }
    #endif

    /// Create the quake controller and register its global hotkey when enabled
    /// with a valid chord. Fail-soft: a failed `RegisterEventHotKey` (e.g. a
    /// reserved combo) is logged; the panel just can't be summoned by the hotkey
    /// (in DEBUG the harness's toggle action still drives it). Design D11.
    private func setUpQuickTerminal(_ settings: QuickTerminalSettings) {
        guard settings.enabled, let spec = settings.hotKey else { return }
        let controller = QuickTerminalController(config: configSet.base.config)
        quickTerminal = controller
        quickTerminalHotKey = GlobalHotKey(spec: spec) { [weak controller] in
            controller?.toggle()
        }
        if quickTerminalHotKey == nil {
            NSLog("[xtty] quick-terminal: could not register the global hotkey (%@); it may be reserved", spec.display)
        }
    }

    #if DEBUG
    /// XCUITest hook: drive the exact `toggle()` the global hotkey calls (a real
    /// global keypress can't be synthesized by XCUITest). Routed via the responder
    /// chain to this delegate from the DEBUG "Toggle Quick Terminal" menu item.
    @objc func toggleQuickTerminalForTest(_ sender: Any?) {
        quickTerminal?.toggle()
    }

    /// XCUITest hook: if the test wrote a synthetic link file, route it through the
    /// key window's focused pane (records the resolved action in the state dump
    /// without launching an editor), then consume the file. Polled by the dump
    /// timer — a real Cmd-click over a detected link in the custom-drawn view can't
    /// be reliably synthesized, and a file poll avoids menu-interaction flakiness.
    private func routePendingTestLink() {
        // The sandboxed UI-test runner can't write to /tmp, so it writes the link
        // to its own (writable) temp dir and passes that path here; the non-sandboxed
        // app reads it. Unset for every test except the file-link suite → no-op.
        guard let path = ProcessInfo.processInfo.environment["XTTY_TEST_LINK_PATH"], !path.isEmpty,
              let link = try? String(contentsOfFile: path, encoding: .utf8)
                  .trimmingCharacters(in: .whitespacesAndNewlines), !link.isEmpty else { return }
        try? FileManager.default.removeItem(atPath: path)
        let key = NSApp.keyWindow
        (windowControllers.first { $0.window === key } ?? windowControllers.last)?
            .routeTestLinkOnActivePane(link)
    }

    /// XCUITest hook: if the test wrote a spatial-op file (`jump-prev` / `jump-next`
    /// / `copy`), drive it on the key window's focused pane (records the resolved
    /// jump target / copied output in the state dump, no real clipboard/scroll
    /// dependency), then consume the file. Same file-poll rationale as the link hook.
    private func routePendingTestSpatialOp() {
        guard let path = ProcessInfo.processInfo.environment["XTTY_TEST_SPATIAL_PATH"], !path.isEmpty,
              let op = try? String(contentsOfFile: path, encoding: .utf8)
                  .trimmingCharacters(in: .whitespacesAndNewlines), !op.isEmpty else { return }
        try? FileManager.default.removeItem(atPath: path)
        let key = NSApp.keyWindow
        (windowControllers.first { $0.window === key } ?? windowControllers.last)?
            .routeTestSpatialOpOnActivePane(op)
    }

    /// XCUITest hook: if the test wrote a git-select file (a changed-file path),
    /// select it in the key window's git-review panel (loads + records its diff in
    /// the state dump), then consume the file. Same file-poll rationale as the link
    /// and spatial hooks.
    private func routePendingTestGitSelect() {
        guard let path = ProcessInfo.processInfo.environment["XTTY_TEST_GIT_SELECT"], !path.isEmpty,
              let sel = try? String(contentsOfFile: path, encoding: .utf8)
                  .trimmingCharacters(in: .whitespacesAndNewlines), !sel.isEmpty else { return }
        try? FileManager.default.removeItem(atPath: path)
        let key = NSApp.keyWindow
        (windowControllers.first { $0.window === key } ?? windowControllers.last)?
            .routeTestGitSelectOnActivePane(sel)
    }

    /// XCUITest hook: if the test wrote a git-open file (a changed-file path), route
    /// it through the git-review open pipeline (records `lastLinkOpen` without
    /// launching an editor), then consume the file.
    private func routePendingTestGitOpen() {
        guard let path = ProcessInfo.processInfo.environment["XTTY_TEST_GIT_OPEN"], !path.isEmpty,
              let target = try? String(contentsOfFile: path, encoding: .utf8)
                  .trimmingCharacters(in: .whitespacesAndNewlines), !target.isEmpty else { return }
        try? FileManager.default.removeItem(atPath: path)
        let key = NSApp.keyWindow
        (windowControllers.first { $0.window === key } ?? windowControllers.last)?
            .routeTestGitOpenOnActivePane(target)
    }

    private func startUITestDump() {
        dumpTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.routePendingTestLink()
                self.routePendingTestSpatialOp()
                self.routePendingTestGitSelect()
                self.routePendingTestGitOpen()
                let key = NSApp.keyWindow
                // When the quake panel is key, its pane is the content under test,
                // but the inventory must still come from a main window so the quake
                // stays excluded from the pane/tab counts. The `key` lookup never
                // matches (the panel isn't a controller), so it falls back to a main
                // window; that list is non-empty whenever a quake is key (an empty
                // list would have terminated the app), and `?.` guards it anyway.
                if let quake = self.quickTerminal, quake.isPanelKey {
                    quake.writeGridDump()
                    (self.windowControllers.first { $0.window === key }
                        ?? self.windowControllers.last)?.writeStateDump()
                } else {
                    let controller = self.windowControllers.first { $0.window === key }
                        ?? self.windowControllers.last
                    controller?.writeUITestDumps()
                }
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
        #if DEBUG
        dumpTimer?.invalidate()  // stop the harness dump timer on quit (P7c hygiene)
        dumpTimer = nil
        #endif
        for controller in windowControllers { controller.terminate() }
        quickTerminal?.terminate()
        quickTerminalHotKey = nil  // deinit unregisters the global hotkey
    }

    // MARK: WindowCoordinator

    @discardableResult
    func openNewWindow() -> TerminalWindowController {
        makeWindow(profile: configSet.defaultProfile)
    }

    /// Create a window/tab controller for a specific profile, wired to this
    /// coordinator. The app-level dump timer covers every window.
    @discardableResult
    private func makeWindow(profile: XttyProfile) -> TerminalWindowController {
        let controller = TerminalWindowController(
            profile: profile, registry: registry, confirmClose: configSet.confirmClose,
            gitReviewLayout: configSet.gitReviewLayout, renderer: configSet.renderer
        )
        controller.coordinator = self
        windowControllers.append(controller)
        return controller
    }

    func openNewTab(relativeTo controller: TerminalWindowController) {
        openNewTab(relativeTo: controller, profile: configSet.defaultProfile)
    }

    func openNewTab(relativeTo controller: TerminalWindowController, profile: XttyProfile) {
        let newController = makeWindow(profile: profile)
        // Group it as a native tab of the originating window.
        controller.window.addTabbedWindow(newController.window, ordered: .above)
        newController.window.makeKeyAndOrderFront(nil)
    }

    /// "New Tab with Profile ▸ <name>" — open a tab using the chosen profile,
    /// relative to the key window (or a fresh window if none). Routed here via the
    /// responder chain from the menu item (its `representedObject` is the name).
    @objc func newTabWithProfile(_ sender: NSMenuItem) {
        let profile = configSet.profile(named: sender.representedObject as? String)
        if let key = NSApp.keyWindow,
           let controller = windowControllers.first(where: { $0.window == key }) {
            openNewTab(relativeTo: controller, profile: profile)
        } else {
            makeWindow(profile: profile).window.makeKeyAndOrderFront(nil)
        }
    }

    /// Build the `Tab ▸ Pane` sidebar snapshot for `controller`'s native tab group
    /// (the session-progress sidebar, P5). Each tab window in the group maps to its
    /// controller; quick-terminal (a separate private registry) is never a
    /// controller, so it stays excluded.
    func sidebarTabs(forTabGroupOf controller: TerminalWindowController) -> [SidebarTabItem] {
        let group = controller.window.tabbedWindows ?? [controller.window]
        return group.compactMap { window -> SidebarTabItem? in
            guard let c = windowControllers.first(where: { $0.window === window }) else { return nil }
            return SidebarTabItem(
                id: window.windowNumber,
                title: c.tabTitle,
                isCurrent: c === controller,
                panes: c.paneItems()
            )
        }
    }

    /// Focus a pane by id from the sidebar — route to its owning tab/window.
    func focusPane(_ id: PaneID) {
        windowControllers.first { $0.owns(id) }?.focusPane(id)
    }

    /// View ▸ Toggle Sidebar — routed via the responder chain to the app delegate;
    /// toggles the key window's sidebar.
    @objc func toggleSidebar(_ sender: Any?) {
        let key = NSApp.keyWindow
        (windowControllers.first { $0.window === key } ?? windowControllers.last)?.toggleSidebar()
    }

    /// View ▸ Toggle Git Review — toggles the key window's git-review panel (P6a).
    @objc func toggleGitReview(_ sender: Any?) {
        let key = NSApp.keyWindow
        (windowControllers.first { $0.window === key } ?? windowControllers.last)?.toggleGitReview()
    }

    func windowControllerDidClose(_ controller: TerminalWindowController) {
        // Defer releasing the controller (and thus its window/views) to the next
        // runloop, so they outlive the in-progress close display cycle.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.windowControllers.removeAll { $0 === controller }
            // The quick terminal is an accessory: once the last main window is
            // gone, a lingering (possibly visible) panel must not keep the app
            // alive (design D8). The no-quake path keeps relying on AppKit's
            // applicationShouldTerminateAfterLastWindowClosed.
            if self.windowControllers.isEmpty, self.quickTerminal != nil {
                self.quickTerminal?.terminate()
                self.quickTerminal = nil
                self.quickTerminalHotKey = nil
                NSApp.terminate(nil)
            }
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
    private static func loadConfigAndKeybindings() -> (XttyConfigSet, Keybindings, QuickTerminalSettings) {
        let environment = ProcessInfo.processInfo.environment
        let path = XttyConfigLoader.configPath(environment: environment, homeDirectory: NSHomeDirectory())
        let text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        let warn: (String) -> Void = { NSLog("[xtty] config: %@", $0) }

        // Profiles add `[profile "name"]` sections; the base (pre-header) pairs
        // carry the global keybinding + quick-terminal keys, which stay base-only.
        let (basePairs, _) = XttyConfigLoader.parseSections(text, warn: warn)
        var configSet = XttyConfigLoader.resolveSet(from: text, warn: warn)
        let keybindings = KeybindResolver.resolve(from: basePairs, warn: warn)
        // Quick-terminal keys live in their own capability (parsed from the same
        // single read), so the terminal-configuration schema stays untouched.
        let quickTerminal = HotKeyResolver.resolve(from: basePairs, warn: warn)
        #if DEBUG
        configSet = applyUITestOverrides(to: configSet)
        #endif
        return (configSet, keybindings, quickTerminal)
    }

    #if DEBUG
    /// XCUITest determinism overrides applied at launch:
    /// - `-UITestScrollback <n>` shrinks the scrollback cap so the bounded-scrollback
    ///   flood test runs fast with an exact saturation point.
    /// - `-UITestRenderer <coregraphics|metal>` forces the rendering backend so the
    ///   CoreGraphics-vs-Metal A/B can run without rebuilding (P7a).
    /// Every other field is carried through unchanged.
    private static func applyUITestOverrides(to set: XttyConfigSet) -> XttyConfigSet {
        let args = ProcessInfo.processInfo.arguments

        var base = set.base.config
        if let i = args.firstIndex(of: "-UITestScrollback"),
           i + 1 < args.count, let n = Int(args[i + 1]), n >= 0 {
            base.scrollback = n
        }

        var renderer = set.renderer
        if let i = args.firstIndex(of: "-UITestRenderer"),
           i + 1 < args.count, let value = RendererBackend(rawValue: args[i + 1].lowercased()) {
            renderer = value
        }

        let newBase = XttyProfile(name: set.base.name, config: base, launch: set.base.launch)
        return XttyConfigSet(
            base: newBase, profiles: set.profiles,
            defaultProfileName: set.defaultProfileName, confirmClose: set.confirmClose,
            gitReviewLayout: set.gitReviewLayout, renderer: renderer
        )
    }
    #endif
}
