import Foundation

/// How a split arranges its children. Named by child layout direction (like CSS
/// flex-direction) to avoid the perennial "vertical split" ambiguity:
/// - `.row`    — children left-to-right, panes **side by side** ("split right").
/// - `.column` — children top-to-bottom, panes **stacked** ("split down").
public enum SplitAxis: Sendable {
    case row
    case column
}

/// The recursive split tree for one window/tab: a leaf is a single `Pane`; an
/// internal node arranges children along a `SplitAxis`. Splits are **n-ary** —
/// three panes side by side are one `.split(.row, [a, b, c])`, not nested pairs.
///
/// The tree is view-free and carries **structure + identity only**; divider
/// positions (ratios) live in the AppKit `NSSplitView` layer, not here. Geometry
/// and per-pane focus ride SwiftTerm/AppKit; `XttyCore` owns just the shape, so
/// the transforms below are pure and unit-testable.
public indirect enum PaneNode {
    case leaf(Pane)
    case split(axis: SplitAxis, children: [PaneNode])

    /// All panes in this subtree, left-to-right / top-to-bottom (in-order).
    public func leaves() -> [Pane] {
        switch self {
        case .leaf(let pane):
            return [pane]
        case .split(_, let children):
            return children.flatMap { $0.leaves() }
        }
    }

    /// Whether `id` is present in this subtree.
    public func contains(_ id: PaneID) -> Bool {
        leaves().contains { $0.id == id }
    }

    /// Split the leaf identified by `targetID`, placing `newPane` alongside it
    /// along `axis`. If the leaf's enclosing split already runs along `axis`, the
    /// new pane is inserted as a **sibling** (keeping splits n-ary); otherwise the
    /// leaf is replaced by a fresh 2-child split. Returns the tree unchanged if
    /// `targetID` is absent.
    public func inserting(_ newPane: Pane, splitting targetID: PaneID, axis: SplitAxis) -> PaneNode {
        switch self {
        case .leaf(let pane):
            guard pane.id == targetID else { return self }
            return .split(axis: axis, children: [.leaf(pane), .leaf(newPane)])

        case .split(let nodeAxis, let children):
            // N-ary case: this split runs along the requested axis and directly
            // contains the target leaf → insert the new pane right after it.
            if nodeAxis == axis,
               let idx = children.firstIndex(where: { node in
                   if case .leaf(let p) = node { return p.id == targetID }
                   return false
               }) {
                var updated = children
                updated.insert(.leaf(newPane), at: idx + 1)
                return .split(axis: nodeAxis, children: updated)
            }
            // Otherwise recurse (a nested split, or a leaf needing a new axis).
            return .split(
                axis: nodeAxis,
                children: children.map { $0.inserting(newPane, splitting: targetID, axis: axis) }
            )
        }
    }

    /// Remove the leaf identified by `id`. A split left with a single child
    /// **collapses** (the survivor is promoted); a split left empty is removed.
    /// Returns `nil` when removal empties the whole tree (caller closes the
    /// tab/window). Returns the tree unchanged if `id` is absent.
    public func removing(_ id: PaneID) -> PaneNode? {
        switch self {
        case .leaf(let pane):
            return pane.id == id ? nil : self

        case .split(let axis, let children):
            let remaining = children.compactMap { $0.removing(id) }
            switch remaining.count {
            case 0: return nil
            case 1: return remaining[0]            // collapse single-child split
            default: return .split(axis: axis, children: remaining)
            }
        }
    }
}
