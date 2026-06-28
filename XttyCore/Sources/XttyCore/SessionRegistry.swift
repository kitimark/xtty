import Foundation
import Observation

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
///
/// It is `@Observable` so the SwiftUI session sidebar re-renders when the
/// inventory, focus, or per-session activity changes. Structure mutations
/// (register/unregister/focus) bump `revision` directly; block/state transitions
/// — which live on the sessions, not here — are signalled via `noteActivityChange()`
/// from the app's main-actor OSC handlers, so the sidebar stays event-driven with
/// no polling.
@MainActor
@Observable
public final class SessionRegistry {
    /// Every live pane by id.
    public private(set) var panes: [PaneID: Pane] = [:]

    /// The currently focused pane, or `nil` when none is focused.
    public private(set) var focused: PaneID?

    /// A monotonic counter bumped on every change the sidebar should react to —
    /// the single value a SwiftUI view observes to recompute its snapshot.
    public private(set) var revision: Int = 0

    @ObservationIgnored private var nextID: UInt64 = 0

    public init() {}

    /// Signal a per-session state change (e.g. an OSC 133 command boundary or an
    /// alternate-screen transition) that doesn't alter the inventory but should
    /// refresh the sidebar. Called from the app's main-actor feed handlers.
    public func noteActivityChange() {
        revision &+= 1
    }

    /// Allocate a fresh, never-reused pane id.
    public func makePaneID() -> PaneID {
        defer { nextID &+= 1 }
        return PaneID(nextID)
    }

    /// Convenience: allocate an id and wrap `session` in a registered `Pane`,
    /// tagged with the profile it launched with (`nil` = base).
    @discardableResult
    public func makePane(for session: TerminalSession, profileName: String? = nil) -> Pane {
        let pane = Pane(id: makePaneID(), session: session, profileName: profileName)
        register(pane)
        return pane
    }

    public func register(_ pane: Pane) {
        panes[pane.id] = pane
        revision &+= 1
    }

    /// Remove a pane; clears focus if the removed pane held it.
    public func unregister(_ id: PaneID) {
        panes.removeValue(forKey: id)
        if focused == id { focused = nil }
        revision &+= 1
    }

    /// Set (or clear) the focused pane. Setting focus to an unregistered id is
    /// ignored, so focus never points at a pane that no longer exists.
    public func setFocus(_ id: PaneID?) {
        guard let id else { focused = nil; revision &+= 1; return }
        if panes[id] != nil { focused = id; revision &+= 1 }
    }

    /// All live sessions (order unspecified) — the enumeration seam for P5/agents.
    public var allSessions: [TerminalSession] {
        panes.values.map { $0.session }
    }
}
