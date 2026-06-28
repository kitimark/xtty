import AppKit
import CoreGraphics
import SwiftUI
import SwiftTerm
import XttyCore

/// Opens new top-level windows/tabs on behalf of a window controller (owned by
/// the app delegate, which holds the shared registry + config).
@MainActor
protocol WindowCoordinator: AnyObject {
    /// Open a new window/tab using the default profile.
    @discardableResult func openNewWindow() -> TerminalWindowController
    func openNewTab(relativeTo controller: TerminalWindowController)
    /// Open a new tab using a specific profile ("New Tab with Profile ▸").
    func openNewTab(relativeTo controller: TerminalWindowController, profile: XttyProfile)
    func windowControllerDidClose(_ controller: TerminalWindowController)

    /// Build the `Tab ▸ Pane` sidebar snapshot for the tab group `controller`
    /// belongs to (the session-progress sidebar, P5). View-free value snapshot.
    func sidebarTabs(forTabGroupOf controller: TerminalWindowController) -> [SidebarTabItem]
    /// Focus a pane by id from the sidebar — bringing its tab/window forward.
    func focusPane(_ id: PaneID)
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

    private let registry: SessionRegistry
    /// Whether to confirm closing a pane with a running foreground job
    /// (the `confirm-close` config key — design D10).
    private let confirmCloseEnabled: Bool

    /// The split-tree structure (view-free model) and the controllers backing it.
    private var tree: PaneNode
    private var panes: [PaneID: PaneController] = [:]
    private var activePaneID: PaneID

    private var keyObserver: NSObjectProtocol?
    private var closeObserver: NSObjectProtocol?
    private var clickMonitor: Any?
    private var isTerminated = false

    // MARK: Sidebar layout
    /// The default sidebar width when shown.
    private static let sidebarWidth: CGFloat = 220
    /// Hosts the pane-tree `NSSplitView`s; the trailing panel beside the sidebar.
    private let terminalContainer = NSView()
    /// The SwiftUI session-progress sidebar (`NSHostingView`), leading panel.
    private var sidebarHost: NSView?
    /// Width constraint toggled to collapse/expand the sidebar.
    private var sidebarWidthConstraint: NSLayoutConstraint?
    private(set) var sidebarVisible = true

    init(profile: XttyProfile, registry: SessionRegistry, confirmClose: Bool = true,
         contentSize: NSSize = NSSize(width: 900, height: 560)) {
        self.registry = registry
        self.confirmCloseEnabled = confirmClose
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        let root = PaneController(
            profile: profile, registry: registry,
            frame: NSRect(origin: .zero, size: contentSize)
        )
        self.tree = .leaf(root.pane)
        self.activePaneID = root.pane.id
        super.init()

        root.delegate = self
        panes[root.pane.id] = root

        window.title = "xtty"
        // The controller owns the window's lifetime; closing must NOT release it,
        // or AppKit's deferred touch-bar/display-cycle update can touch freed views
        // (EXC_BAD_ACCESS in objc_release). It's freed when the controller is.
        window.isReleasedWhenClosed = false
        // The window content is [ sidebar | terminalContainer ]; the pane-tree
        // (single leaf now, NSSplitViews after a split) lives in terminalContainer.
        buildLayout(terminalRoot: root.view)
        // Native macOS window tabbing: a tab IS a window (Ghostty model). Shared
        // identifier groups xtty windows; macOS provides the tab bar, Cmd+Shift+[/],
        // drag-tab-out, and Merge All for free.
        window.tabbingMode = .preferred
        window.tabbingIdentifier = NSWindow.TabbingIdentifier("xtty")
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

        // When the window (a tab) closes — by the red button, escalation, or
        // drag-out merge — terminate its panes and drop it from the coordinator,
        // so no orphan shells remain and the controller list stays accurate.
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.coordinator?.windowControllerDidClose(self)
                self.terminate()
            }
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

    // MARK: Sidebar layout + public surface

    /// Build `window.contentView` as [ sidebar | terminalContainer ] using Auto
    /// Layout (a fixed-width, collapsible leading sidebar), then place the initial
    /// pane-tree root inside the terminal container.
    private func buildLayout(terminalRoot: NSView) {
        let container = NSView()
        let host = NSHostingView(rootView: makeSidebarRootView())
        host.translatesAutoresizingMaskIntoConstraints = false
        terminalContainer.translatesAutoresizingMaskIntoConstraints = false
        sidebarHost = host
        container.addSubview(host)
        container.addSubview(terminalContainer)
        let widthC = host.widthAnchor.constraint(equalToConstant: Self.sidebarWidth)
        sidebarWidthConstraint = widthC
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.topAnchor.constraint(equalTo: container.topAnchor),
            host.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            widthC,
            terminalContainer.leadingAnchor.constraint(equalTo: host.trailingAnchor),
            terminalContainer.topAnchor.constraint(equalTo: container.topAnchor),
            terminalContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            terminalContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        window.contentView = container
        setTerminalRoot(terminalRoot)
    }

    /// Place a pane-tree root view inside the terminal container (autoresizing to
    /// fill it), replacing any previous tree.
    private func setTerminalRoot(_ view: NSView) {
        terminalContainer.subviews.forEach { $0.removeFromSuperview() }
        view.translatesAutoresizingMaskIntoConstraints = true
        view.frame = terminalContainer.bounds
        view.autoresizingMask = [.width, .height]
        terminalContainer.addSubview(view)
    }

    /// The SwiftUI sidebar root, wired to the coordinator for the tab-group
    /// snapshot and pane focus. Before the coordinator is attached (initial render),
    /// it falls back to just this tab so the first pane shows immediately.
    private func makeSidebarRootView() -> SessionSidebarView {
        SessionSidebarView(
            registry: registry,
            tabsProvider: { [weak self] in
                guard let self else { return [] }
                if let coordinator = self.coordinator {
                    return coordinator.sidebarTabs(forTabGroupOf: self)
                }
                return [SidebarTabItem(id: self.window.windowNumber, title: self.tabTitle,
                                       isCurrent: true, panes: self.paneItems())]
            },
            onActivate: { [weak self] id in self?.coordinator?.focusPane(id) }
        )
    }

    /// Toggle the sidebar's visibility (View ▸ Toggle Sidebar).
    func toggleSidebar() {
        sidebarVisible.toggle()
        sidebarWidthConstraint?.constant = sidebarVisible ? Self.sidebarWidth : 0
        sidebarHost?.isHidden = !sidebarVisible
    }

    /// This tab's title (the window title), shown as the sidebar section header.
    var tabTitle: String { window.title }

    /// Whether this tab's pane tree contains `id` (the coordinator routes focus).
    func owns(_ id: PaneID) -> Bool { tree.contains(id) }

    /// Focus a pane in this tab by id and bring its window/tab forward (the
    /// sidebar's click target — focus only, never scroll-to-row).
    func focusPane(_ id: PaneID) {
        guard tree.contains(id) else { return }
        setActivePane(id)
        window.makeKeyAndOrderFront(nil)
    }

    /// Snapshot this tab's panes for the sidebar (in tree order).
    func paneItems() -> [SidebarPaneItem] {
        tree.leaves().map { pane in
            let session = pane.session
            return SidebarPaneItem(
                id: pane.id,
                label: pane.profileName ?? "shell",
                activity: session.activity,
                lastCommand: session.blocks.blocks.last?.command,
                runningSince: session.blocks.runningBlock?.startedAt,
                runningCommand: session.runningCommand,
                isActive: pane.id == activePaneID
            )
        }
    }

    /// Terminate every pane in this window and remove observers. Idempotent
    /// (fires from both `willClose` and app quit).
    func terminate() {
        if isTerminated { return }
        isTerminated = true
        for observer in [keyObserver, closeObserver].compactMap({ $0 }) {
            NotificationCenter.default.removeObserver(observer)
        }
        keyObserver = nil
        closeObserver = nil
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
        // Confirm only on user-initiated close of a pane with a running foreground
        // job (shell-exit goes through paneDidTerminate, which never prompts).
        if confirmCloseEnabled, hasForegroundJob(pane.view), !confirmClose() {
            return
        }
        closePane(pane)
    }

    /// Whether the pane's terminal has a foreground process group other than the
    /// shell itself (i.e. a command is running). Standard `tcgetpgrp` check.
    private func hasForegroundJob(_ view: XttyTerminalView) -> Bool {
        let process = view.process
        let fd = process?.childfd ?? -1
        let shellPid = process?.shellPid ?? 0
        guard fd >= 0, shellPid > 0 else { return false }
        let foreground = tcgetpgrp(fd)
        return foreground > 0 && foreground != shellPid
    }

    private func confirmClose() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Close this pane?"
        alert.informativeText = "A process is still running."
        alert.addButton(withTitle: "Close")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
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
        // A split inherits the focused pane's profile (appearance + launch
        // overrides), so splitting an ssh/profiled pane yields another like it.
        let inherited = panes[activePaneID]?.profile ?? PaneController.baseProfile
        // …and opens in the focused pane's current (live) directory when known,
        // falling back to the profile's own start directory (startDirectory nil).
        let startDirectory = panes[activePaneID]?.pane.session.liveLocalDirectory
        let newPane = PaneController(
            profile: inherited, registry: registry,
            frame: NSRect(origin: .zero, size: NSSize(width: 400, height: 300)),
            startDirectory: startDirectory
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
            // Detach the first responder before closing: otherwise the touch-bar /
            // responder machinery can reference the focused custom view as it's torn
            // down during the display cycle (EXC_BAD_ACCESS in objc_release).
            window.makeFirstResponder(nil)
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
        let size = terminalContainer.bounds.size
        let root = makeView(for: tree, size: size)
        root.frame = NSRect(origin: .zero, size: size)
        root.autoresizingMask = [.width, .height]
        setTerminalRoot(root)
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
    /// Write this window's focused-pane grid + multiplexing inventory to the temp
    /// files the XCUITest harness reads. Called by the app delegate's single dump
    /// timer for the **key** window's controller, so multiple tab/window
    /// controllers never fight over the shared path. The custom-drawn view has no
    /// AX text, so this engine grid is the deterministic content source.
    func writeUITestDumps() {
        writeGridDump()
        writeStateDump()
    }

    /// The content channel: the focused pane's engine grid. Split out so the quick
    /// terminal can write its own grid when its panel is key (the app timer then
    /// pairs it with a main window's `writeStateDump()`).
    func writeGridDump() {
        guard let active = panes[activePaneID] else { return }
        UITestDump.writeGrid(engine: active.engine)
    }

    /// The structure channel: this window's multiplexing inventory + config knobs.
    /// Always sourced from a main window controller, so the quick terminal (which
    /// uses a private registry and is not a controller) never affects the counts.
    func writeStateDump() {
        guard let active = panes[activePaneID] else { return }
        let engine = active.engine
        let depth = engine.getTopVisibleRow()
        let leaves = tree.leaves()
        let session = active.pane.session
        // Semantic capture (P4a): the live cwd, alt-screen state, and block list.
        let blocks: [[String: Any]] = session.blocks.blocks.map { b in
            [
                "command": b.command ?? "",
                "exitCode": b.exitCode.map { NSNumber(value: $0) } ?? NSNull(),
                "state": b.state.rawValue,
            ]
        }
        let state: [String: Any] = [
            "fontFamily": active.view.font.familyName ?? active.view.font.fontName,
            "fontSize": Double(active.view.font.pointSize),
            "theme": active.profile.config.themeName,
            "scrollbackCap": active.profile.config.scrollback,
            "optionAsMeta": active.view.optionAsMetaKey,
            "rows": engine.rows,
            "isAlt": engine.isCurrentBufferAlternate,
            "scrollbackDepth": depth,
            "bufferLines": depth + engine.rows,
            // Multiplexing inventory.
            "paneCount": leaves.count,
            "focusedPaneIndex": leaves.firstIndex(where: { $0.id == activePaneID }) ?? -1,
            "tabCount": window.tabbedWindows?.count ?? 1,
            // Profile of the focused pane (empty string = base profile).
            "profileName": active.pane.profileName ?? "",
            "cwd": active.pane.session.launchConfig.cwd ?? "",
            // Semantic capture.
            "currentDirectory": session.currentWorkingDirectory?.path ?? "",
            "isAlternateScreen": session.isAlternateScreen,
            "lastSemanticAction": Self.actionName(session.blocks.lastAction),
            "blocks": blocks,
            // Session-progress sidebar (P5): the derived activity + running command.
            "sessionActivity": session.activity.rawValue,
            "runningCommand": session.runningCommand ?? "",
            // File-link opening (P4b-1): the last resolved link-open action.
            "lastLinkOpen": Self.linkOpenDump(active.lastLinkOpen),
        ]
        if let data = try? JSONSerialization.data(withJSONObject: state, options: [.sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: UITestDump.stateDumpPath))
        }
    }

    /// Short name for a semantic action (for the DEBUG dump).
    private static func actionName(_ action: SemanticAction?) -> String {
        switch action {
        case .promptStart: return "A"
        case .promptEnd: return "B"
        case .commandStart: return "C"
        case .commandEnd: return "D"
        case nil: return ""
        }
    }

    /// XCUITest hook: resolve a synthetic link on the focused pane through the real
    /// pipeline + live cwd, recording the action for the state dump (no editor
    /// launch). Paired with the Debug ▸ "Route Test Link" menu item.
    func routeTestLinkOnActivePane(_ link: String) {
        panes[activePaneID]?.routeTestLink(link)
    }

    /// Serialize the last resolved link-open action for the harness state dump.
    private static func linkOpenDump(_ resolution: LinkOpenResolution?) -> [String: Any] {
        guard let resolution else { return ["action": "none"] }
        switch resolution {
        case let .open(target, _):
            switch target {
            case let .file(path, line, column):
                return [
                    "action": "opened", "kind": "file", "path": path,
                    "line": line.map { NSNumber(value: $0) } ?? NSNull(),
                    "column": column.map { NSNumber(value: $0) } ?? NSNull(),
                ]
            case let .url(scheme, raw):
                return ["action": "opened", "kind": "url", "scheme": scheme, "path": raw]
            }
        case let .blocked(scheme):
            return ["action": "blocked", "scheme": scheme]
        case let .unresolved(reason):
            return ["action": "noop", "reason": reason]
        }
    }
    #endif
}
