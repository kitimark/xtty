import Foundation

/// A stable identifier for a pane, unique within a `SessionRegistry`.
///
/// Opaque to the view layer: the AppKit side keys its views off this id rather
/// than off view object identity, so the structural model in `XttyCore` stays
/// the source of truth for *which* panes exist.
public struct PaneID: Hashable, Sendable {
    public let value: UInt64
    public init(_ value: UInt64) { self.value = value }
}

/// One pane: an entity-with-identity wrapping a single `TerminalSession`.
///
/// This is the unit P3 multiplies — today one window owns one session, now a
/// window owns a *tree* of panes (see `PaneNode`). `Pane` is deliberately
/// view-free: it references only the observe-only `TerminalSession` (and thus
/// SwiftTerm's headless engine), never a terminal view. The AppKit layer maps a
/// `Pane` to a `LocalProcessTerminalView`; `XttyCore` never sees that view.
public final class Pane {
    public let id: PaneID
    public let session: TerminalSession

    public init(id: PaneID, session: TerminalSession) {
        self.id = id
        self.session = session
    }
}
