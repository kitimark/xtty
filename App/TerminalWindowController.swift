import AppKit
import CoreGraphics
import SwiftTerm
import XttyCore

/// Opens new top-level windows/tabs on behalf of a window controller (owned by
/// the app delegate, which holds the shared registry + config).
@MainActor
protocol WindowCoordinator: AnyObject {
    func openNewWindow()
    func openNewTab(relativeTo controller: TerminalWindowController)
}

/// Owns one xtty window/tab and the **tree of panes** inside it.
///
/// **Why AppKit, not SwiftUI:** SwiftTerm's view draws into a hand-managed
/// `CALayer` that SwiftUI's `NSViewRepresentable` host does not composite on
/// macOS 26 (the canvas stays black); a plain `NSWindow` composites it. So panes
/// are hosted directly in AppKit.
///
/// The controller owns a `PaneNode` split tree and the `PaneController`s backing
/// its leaves, rendering the tree as nested `NSSplitView`s. Each pane's engine
/// flows through `XttyCore.TerminalSession`, registered in the shared
/// `SessionRegistry`; per-pane focus + commands ride the responder chain.
@MainActor
final class TerminalWindowController: NSObject, PaneControllerDelegate {
    let window: NSWindow
    weak var coordinator: WindowCoordinator?

    private let config: XttyConfig
    private let registry: SessionRegistry

    /// The split-tree structure (view-free model) and the controllers backing it.
    private var tree: PaneNode
    private var panes: [PaneID: PaneController] = [:]
    private var activePaneID: PaneID

    private var keyObserver: NSObjectProtocol?
    private var clickMonitor: Any?
    #if DEBUG
    private var gridDumpTimer: Timer?
    #endif

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
        window.contentView = root.view  // single leaf; splits build NSSplitViews
        window.tabbingMode = .disallowed  // layer 3 flips to .preferred
        window.setAccessibilityIdentifier("xtty.window")
        window.identifier = NSUserInterfaceItemIdentifier("xtty.window")

        positionOnBuiltInDisplay()
        window.makeKeyAndOrderFront(nil)
        focusActivePane()

        keyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.focusActivePane() }
        }

        // Track click-to-focus: SwiftTerm's view makes itself first responder on
        // click, but `becomeFirstResponder` is not overridable (SwiftTerm declares
        // it `public`, not `open`), so we observe clicks to keep `activePaneID`
        // synced. The monitor only reads the event; it never consumes it.
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            MainActor.assumeIsolated { self?.updateActivePaneFromClick(event) }
            return event
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

    private func setActivePane(_ id: PaneID) {
        guard panes[id] != nil else { return }
        activePaneID = id
        focusActivePane()
    }

    /// Terminate every pane in this window and remove observers.
    func terminate() {
        #if DEBUG
        gridDumpTimer?.invalidate()
        gridDumpTimer = nil
        #endif
        if let keyObserver {
            NotificationCenter.default.removeObserver(keyObserver)
            self.keyObserver = nil
        }
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
        for pane in panes.values { pane.terminate() }
        panes.removeAll()
    }

    /// Sync `activePaneID` to the pane the user clicked (the click itself makes
    /// the view first responder; we only track which pane that is).
    private func updateActivePaneFromClick(_ event: NSEvent) {
        guard event.window == window, let content = window.contentView else { return }
        let point = content.convert(event.locationInWindow, from: nil)
        for leaf in tree.leaves() {
            guard let view = panes[leaf.id]?.view else { continue }
            if view.convert(view.bounds, to: content).contains(point) {
                activePaneID = leaf.id
                registry.setFocus(leaf.id)
                return
            }
        }
    }

    // MARK: PaneControllerDelegate

    func paneDidTerminate(_ pane: PaneController, exitCode: Int32?) {
        closePane(pane)
    }

    func paneDidUpdateTitle(_ pane: PaneController, title: String) {
        if pane.pane.id == activePaneID {
            window.title = title.isEmpty ? "xtty" : title
        }
    }

    func paneRequestsSplit(_ pane: PaneController, axis: SplitAxis) {
        activePaneID = pane.pane.id  // the command fired at this (focused) pane
        splitFocusedPane(axis: axis)
    }

    func paneRequestsClose(_ pane: PaneController) {
        closePane(pane)
    }

    func paneRequestsFocusMove(_ pane: PaneController, direction: FocusDirection) {
        activePaneID = pane.pane.id
        moveFocus(direction)
    }

    func paneRequestsNewTab(_ pane: PaneController) {
        coordinator?.openNewTab(relativeTo: self)
    }

    func paneRequestsNewWindow(_ pane: PaneController) {
        coordinator?.openNewWindow()
    }

    // MARK: Split / close

    private func splitFocusedPane(axis: SplitAxis) {
        let newPane = PaneController(
            config: config, registry: registry,
            frame: NSRect(origin: .zero, size: NSSize(width: 400, height: 300))
        )
        newPane.delegate = self
        panes[newPane.pane.id] = newPane
        tree = tree.inserting(newPane.pane, splitting: activePaneID, axis: axis)
        activePaneID = newPane.pane.id
        rebuildContentView()
    }

    /// Remove a pane; collapse single-child splits. When the tree empties, close
    /// the window (layer 3 adds the full pane → tab → window → quit escalation).
    private func closePane(_ pane: PaneController) {
        pane.terminate()
        panes[pane.pane.id] = nil

        guard let newTree = tree.removing(pane.pane.id) else {
            window.close()
            return
        }
        tree = newTree
        if !tree.contains(activePaneID) {
            activePaneID = tree.leaves().first?.id ?? activePaneID
        }
        rebuildContentView()
    }

    // MARK: Focus navigation (spatial nearest-neighbor over leaf frames)

    private func moveFocus(_ direction: FocusDirection) {
        let leaves = tree.leaves()
        guard leaves.count > 1, let currentView = panes[activePaneID]?.view else { return }
        let current = currentView.convert(currentView.bounds, to: nil)
        let from = NSPoint(x: current.midX, y: current.midY)

        var best: (id: PaneID, distance: CGFloat)?
        for leaf in leaves where leaf.id != activePaneID {
            guard let view = panes[leaf.id]?.view else { continue }
            let frame = view.convert(view.bounds, to: nil)
            let dx = frame.midX - from.x
            let dy = frame.midY - from.y  // AppKit y increases upward

            let inDirection: Bool
            switch direction {
            case .left: inDirection = dx < 0 && abs(dx) >= abs(dy)
            case .right: inDirection = dx > 0 && abs(dx) >= abs(dy)
            case .up: inDirection = dy > 0 && abs(dy) >= abs(dx)
            case .down: inDirection = dy < 0 && abs(dy) >= abs(dx)
            }
            guard inDirection else { continue }
            let distance = abs(dx) + abs(dy)
            if best == nil || distance < best!.distance { best = (leaf.id, distance) }
        }
        if let best { setActivePane(best.id) }
    }

    // MARK: NSSplitView rendering

    /// Rebuild the window content from the current tree (called after split/close).
    /// Divider positions reset to even on each rebuild (ratios are not persisted
    /// in this milestone — design D4).
    private func rebuildContentView() {
        let size = window.contentView?.bounds.size ?? window.frame.size
        let root = makeView(for: tree, size: size)
        root.frame = NSRect(origin: .zero, size: size)
        root.autoresizingMask = [.width, .height]
        window.contentView = root
        if let split = root as? NSSplitView { distributeEvenly(split) }
        focusActivePane()
    }

    /// Recursively build the AppKit view tree for a `PaneNode`.
    private func makeView(for node: PaneNode, size: NSSize) -> NSView {
        switch node {
        case .leaf(let pane):
            let view = panes[pane.id]?.view ?? NSView()
            view.translatesAutoresizingMaskIntoConstraints = true
            return view
        case .split(let axis, let children):
            let split = NSSplitView(frame: NSRect(origin: .zero, size: size))
            split.isVertical = (axis == .row)  // row = panes side by side = vertical divider
            split.dividerStyle = .thin
            split.translatesAutoresizingMaskIntoConstraints = true
            split.autoresizingMask = [.width, .height]
            let n = CGFloat(max(children.count, 1))
            for child in children {
                let childSize = split.isVertical
                    ? NSSize(width: size.width / n, height: size.height)
                    : NSSize(width: size.width, height: size.height / n)
                let childView = makeView(for: child, size: childSize)
                childView.autoresizingMask = [.width, .height]
                split.addSubview(childView)
            }
            return split
        }
    }

    /// Set even divider positions for a split (and its nested splits).
    private func distributeEvenly(_ split: NSSplitView) {
        let count = split.subviews.count
        if count > 1 {
            let total = split.isVertical ? split.bounds.width : split.bounds.height
            let thickness = split.dividerThickness
            let paneLength = (total - thickness * CGFloat(count - 1)) / CGFloat(count)
            for i in 0..<(count - 1) {
                let position = CGFloat(i + 1) * paneLength + CGFloat(i) * thickness
                split.setPosition(position, ofDividerAt: i)
            }
        }
        for sub in split.subviews {
            if let nested = sub as? NSSplitView { distributeEvenly(nested) }
        }
    }

    // MARK: Built-in display placement

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
    private static let gridDumpPath = "/tmp/xtty-grid-dump.txt"
    private static let stateDumpPath = "/tmp/xtty-state-dump.json"

    /// Start the XCUITest grid/state dump. Window-level so it always follows the
    /// **focused** pane (the grid) and reports the multiplexing inventory (pane
    /// count, focused index, tab count) — the deterministic source for the
    /// split/close/focus/tab tests, since the custom-drawn view has no AX text.
    func startGridDumpForUITests() {
        gridDumpTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.writeUITestDumps() }
        }
    }

    private func writeUITestDumps() {
        guard let active = panes[activePaneID] else { return }
        let engine = active.engine

        // Grid of the focused pane. `skipNullCellsFollowingWide` + a
        // `characterProvider` keep wide CJK (NUL spacer 2nd column) and non-BMP/
        // grapheme emoji (map-indexed codes) intact.
        var lines: [String] = []
        lines.reserveCapacity(engine.rows)
        for row in 0..<engine.rows {
            lines.append(engine.getLine(row: row)?.translateToString(
                trimRight: true,
                skipNullCellsFollowingWide: true,
                characterProvider: { engine.getCharacter(for: $0) }
            ) ?? "")
        }
        try? lines.joined(separator: "\n").write(
            toFile: Self.gridDumpPath, atomically: true, encoding: .utf8)

        let depth = engine.getTopVisibleRow()
        let leaves = tree.leaves()
        let state: [String: Any] = [
            "fontFamily": active.view.font.familyName ?? active.view.font.fontName,
            "fontSize": Double(active.view.font.pointSize),
            "theme": config.themeName,
            "scrollbackCap": config.scrollback,
            "optionAsMeta": active.view.optionAsMetaKey,
            "rows": engine.rows,
            "isAlt": engine.isCurrentBufferAlternate,
            "scrollbackDepth": depth,
            "bufferLines": depth + engine.rows,
            // Multiplexing inventory.
            "paneCount": leaves.count,
            "focusedPaneIndex": leaves.firstIndex(where: { $0.id == activePaneID }) ?? -1,
            "tabCount": window.tabbedWindows?.count ?? 1,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: state, options: [.sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: Self.stateDumpPath))
        }
    }
    #endif
}
