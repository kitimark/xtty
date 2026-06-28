import AppKit
import CoreGraphics
import SwiftTerm
import XttyCore

/// A borderless, non-activating panel that can become key so the quake terminal
/// receives typing without activating xtty's main windows (design D4).
private final class QuickTerminalPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// The "quake" drop-down terminal: one persistent scratch shell in a panel that
/// a global hotkey toggles in and out (design D4–D8).
///
/// It is an **accessory**: it owns a *private* `SessionRegistry`, so it is
/// excluded from the app's main registry — and thus from the multiplexing
/// inventory and the future P5 sidebar — by construction, with no change to
/// `PaneController` (design D7). The shell is created lazily on first summon and
/// persists across hide/show; only the panel is ordered in/out.
@MainActor
final class QuickTerminalController: NSObject, PaneControllerDelegate {
    private let config: XttyConfig
    /// Private registry — the accessory exclusion seam (D7).
    private let registry = SessionRegistry()
    private var panel: QuickTerminalPanel?
    private var pane: PaneController?

    /// Fraction of the target screen's visible height the panel occupies.
    private static let heightFraction: CGFloat = 0.4

    init(config: XttyConfig) {
        self.config = config
        super.init()
    }

    /// Whether the panel is currently the key window (used by the DEBUG harness).
    var isPanelKey: Bool { panel?.isKeyWindow ?? false }

    /// Summon on the screen under the mouse, hide if already showing there, or —
    /// if showing on a different screen — move it to the mouse's screen
    /// (summon-to-active, design D5).
    func toggle() {
        guard let target = Self.screenUnderMouse() ?? NSScreen.main else { return }
        ensurePanel(on: target)
        guard let panel else { return }
        if panel.isVisible, Self.sameScreen(panel.screen, target) {
            hide()
        } else {
            show(on: target)
        }
    }

    /// Tear down the scratch shell + panel (on app quit, or when the shell exits).
    func terminate() {
        pane?.terminate()
        pane = nil
        panel?.orderOut(nil)
        panel = nil
    }

    // MARK: Panel lifecycle

    private func ensurePanel(on screen: NSScreen) {
        if panel != nil { return }
        let frame = Self.frame(on: screen)
        // Base appearance, but always a plain login shell — ignore any profile
        // launch overrides (command/cwd), so the scratch terminal is never
        // redirected into a command/dir (design D9).
        let profile = XttyProfile(name: nil, config: config, launch: .none)
        let pane = PaneController(profile: profile, registry: registry,
                                  frame: NSRect(origin: .zero, size: frame.size))
        pane.delegate = self
        self.pane = pane

        let panel = QuickTerminalPanel(
            contentRect: frame,
            styleMask: [.nonactivatingPanel, .borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isExcludedFromWindowsMenu = true
        panel.contentView = pane.view
        self.panel = panel
    }

    /// Recompute the frame from the target screen on every show (never cached —
    /// survives resolution change / monitor unplug, design D5) and order in as key.
    private func show(on screen: NSScreen) {
        guard let panel else { return }
        panel.setFrame(Self.frame(on: screen), display: true)
        panel.makeKeyAndOrderFront(nil)
        if let pane { panel.makeFirstResponder(pane.view) }
    }

    private func hide() {
        // Order out (don't close): the shell persists; AppKit returns key/focus to
        // the previously active context (non-activating panel, design D5).
        panel?.orderOut(nil)
    }

    // MARK: Geometry

    /// Full width across the top `heightFraction` of the screen's visible area.
    private static func frame(on screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        let height = (visible.height * heightFraction).rounded()
        return NSRect(x: visible.minX, y: visible.maxY - height,
                      width: visible.width, height: height)
    }

    private static func screenUnderMouse() -> NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(location, $0.frame, false) }
    }

    private static func sameScreen(_ a: NSScreen?, _ b: NSScreen?) -> Bool {
        // Compare by display ID, not frame: distinct displays can share a frame
        // size, and NSScreen objects are recreated across hot-plug, so identity is
        // unreliable. Mirrors TerminalWindowController.builtInScreen().
        guard let a = displayID(of: a), let b = displayID(of: b) else { return false }
        return a == b
    }

    private static func displayID(of screen: NSScreen?) -> CGDirectDisplayID? {
        guard let screen,
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { return nil }
        return CGDirectDisplayID(number.uint32Value)
    }

    // MARK: PaneControllerDelegate
    //
    // The quake is single-pane: split/focus/tab/window requests are no-ops, and a
    // close request hides the panel (the shell persists). A shell exit tears the
    // panel down so the next summon recreates a fresh scratch shell.

    func paneDidTerminate(_ pane: PaneController, exitCode: Int32?) { terminate() }
    func paneDidUpdateTitle(_ pane: PaneController, title: String) {}
    func paneRequestsSplit(_ pane: PaneController, axis: SplitAxis) {}
    func paneRequestsClose(_ pane: PaneController) { hide() }
    func paneRequestsFocusMove(_ pane: PaneController, direction: FocusDirection) {}
    func paneRequestsNewTab(_ pane: PaneController) {}
    func paneRequestsNewWindow(_ pane: PaneController) {}
    func paneDidFinishCommand(_ pane: PaneController) {}  // no git-review panel here

    #if DEBUG
    /// Write the quake pane's grid for the harness (paired with a main window's
    /// `writeStateDump()` by the app timer, so the quake stays out of the counts).
    func writeGridDump() {
        guard let engine = pane?.engine else { return }
        UITestDump.writeGrid(engine: engine)
    }
    #endif
}
