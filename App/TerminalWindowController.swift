import AppKit
import CoreGraphics
import SwiftTerm
import XttyCore

/// Owns one xtty window/tab and the **tree of panes** inside it.
///
/// **Why AppKit, not SwiftUI:** SwiftTerm's `LocalProcessTerminalView` draws its
/// grid into a hand-managed, layer-backed `CALayer`. On macOS 26 SwiftUI's
/// `NSViewRepresentable` host does not composite that subtree (the canvas stays
/// black) — verified for both the CoreGraphics and Metal paths — while a plain
/// `NSWindow` composites it correctly. So panes are hosted directly in AppKit.
///
/// The P3 decomposition: this controller no longer owns a single view. It owns a
/// `PaneNode` split tree (one leaf at layer 1; splits arrive in layer 2) and the
/// `PaneController`s that back its leaves, and routes per-pane lifecycle through
/// the `PaneControllerDelegate` seam. The engine seam is unchanged — each pane's
/// engine handle flows through `XttyCore.TerminalSession`, registered in the
/// shared `SessionRegistry`.
@MainActor
final class TerminalWindowController: NSObject, PaneControllerDelegate {
    let window: NSWindow
    private let config: XttyConfig
    private let registry: SessionRegistry

    /// The split-tree structure (view-free model) and the controllers backing it.
    private var tree: PaneNode
    private var panes: [PaneID: PaneController] = [:]
    private var activePaneID: PaneID

    private var keyObserver: NSObjectProtocol?

    init(config: XttyConfig, registry: SessionRegistry, contentSize: NSSize = NSSize(width: 900, height: 560)) {
        self.config = config
        self.registry = registry
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        let root = PaneController(
            config: config, registry: registry,
            frame: NSRect(origin: .zero, size: contentSize)
        )
        self.tree = .leaf(root.pane)
        self.activePaneID = root.pane.id
        super.init()

        root.delegate = self
        panes[root.pane.id] = root

        window.title = "xtty"
        window.contentView = root.view  // layer 2 wraps the tree in NSSplitViews
        window.tabbingMode = .disallowed  // layer 3 flips to .preferred
        window.setAccessibilityIdentifier("xtty.window")
        window.identifier = NSUserInterfaceItemIdentifier("xtty.window")

        // Open on the built-in display (user's workspace), not an external monitor.
        positionOnBuiltInDisplay()
        window.makeKeyAndOrderFront(nil)
        focusActivePane()

        // Keep the focused pane first responder whenever the window becomes key.
        keyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.focusActivePane() }
        }
    }

    /// The focused pane's controller (used by the DEBUG harness hook).
    var activePane: PaneController? { panes[activePaneID] }

    /// Make the active pane first responder and record focus in the model.
    private func focusActivePane() {
        guard let pane = panes[activePaneID] else { return }
        window.makeFirstResponder(pane.view)
        registry.setFocus(activePaneID)
    }

    /// Terminate every pane in this window and remove observers. Safe to call
    /// multiple times.
    func terminate() {
        if let keyObserver {
            NotificationCenter.default.removeObserver(keyObserver)
            self.keyObserver = nil
        }
        for pane in panes.values { pane.terminate() }
        panes.removeAll()
    }

    // MARK: PaneControllerDelegate

    func paneDidTerminate(_ pane: PaneController, exitCode: Int32?) {
        // Current policy: closing the last pane closes the window (layer 3 adds
        // the full pane → tab → window → quit escalation).
        closePane(pane)
    }

    func paneDidUpdateTitle(_ pane: PaneController, title: String) {
        if pane.pane.id == activePaneID {
            window.title = title.isEmpty ? "xtty" : title
        }
    }

    /// Remove a pane from the tree; collapse single-child splits. When the tree
    /// empties, close the window.
    private func closePane(_ pane: PaneController) {
        pane.terminate()
        panes[pane.pane.id] = nil

        guard let newTree = tree.removing(pane.pane.id) else {
            window.close()  // last pane gone
            return
        }
        tree = newTree
        // Layer 2 rebuilds the NSSplitView host + retargets focus to a neighbor.
        if let next = tree.leaves().first {
            activePaneID = next.id
            focusActivePane()
        }
    }

    // MARK: Built-in display placement

    /// Center the window on the built-in MacBook Pro display (falls back to the
    /// main screen, then to AppKit's default centering).
    private func positionOnBuiltInDisplay() {
        let builtIn = TerminalWindowController.builtInScreen()
        guard let screen = builtIn ?? NSScreen.main else {
            window.center()
            return
        }
        let visible = screen.visibleFrame
        let size = window.frame.size
        let origin = NSPoint(x: visible.midX - size.width / 2,
                             y: visible.midY - size.height / 2)
        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    /// The `NSScreen` backed by the built-in display (`CGDisplayIsBuiltin`), or nil.
    static func builtInScreen() -> NSScreen? {
        for screen in NSScreen.screens {
            let key = NSDeviceDescriptionKey("NSScreenNumber")
            guard let number = screen.deviceDescription[key] as? NSNumber else { continue }
            if CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) != 0 {
                return screen
            }
        }
        return nil
    }

    #if DEBUG
    /// Start the XCUITest grid/state dump on the focused pane.
    func startGridDumpForUITests() {
        activePane?.startGridDumpForUITests()
    }
    #endif
}
