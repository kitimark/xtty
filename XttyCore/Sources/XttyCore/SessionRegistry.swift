import Foundation

/// The set of all live panes across every window/tab, plus which pane is
/// focused. This is the single view-free model that non-view features enumerate
/// — P5's per-window session sidebar, P4's block model, a future agent API —
/// rather than walking the AppKit view tree.
///
/// The AppKit side owns geometry (the `NSSplitView`s, divider positions, first
/// responder); the registry owns identity allocation and the canonical "which
/// panes exist / which is focused" answer. It is `@MainActor` because the app
/// mutates it from the main thread alongside the views; the pure tree transforms
/// live on `PaneNode` and need no isolation.
@MainActor
public final class SessionRegistry {
    /// Every live pane by id.
    public private(set) var panes: [PaneID: Pane] = [:]

    /// The currently focused pane, or `nil` when none is focused.
    public private(set) var focused: PaneID?

    private var nextID: UInt64 = 0

    public init() {}

    /// Allocate a fresh, never-reused pane id.
    public func makePaneID() -> PaneID {
        defer { nextID &+= 1 }
        return PaneID(nextID)
    }

    /// Convenience: allocate an id and wrap `session` in a registered `Pane`.
    @discardableResult
    public func makePane(for session: TerminalSession) -> Pane {
        let pane = Pane(id: makePaneID(), session: session)
        register(pane)
        return pane
    }

    public func register(_ pane: Pane) {
        panes[pane.id] = pane
    }

    /// Remove a pane; clears focus if the removed pane held it.
    public func unregister(_ id: PaneID) {
        panes.removeValue(forKey: id)
        if focused == id { focused = nil }
    }

    /// Set (or clear) the focused pane. Setting focus to an unregistered id is
    /// ignored, so focus never points at a pane that no longer exists.
    public func setFocus(_ id: PaneID?) {
        guard let id else { focused = nil; return }
        if panes[id] != nil { focused = id }
    }

    /// All live sessions (order unspecified) — the enumeration seam for P5/agents.
    public var allSessions: [TerminalSession] {
        panes.values.map { $0.session }
    }
}
