import Foundation

/// XttyCore — the engine-facing seam for xtty.
///
/// This module is intentionally near-empty at P0. Its job is structural: to
/// exist as the place where all terminal logic will live, decoupled from any
/// view. Later milestones add the PTY loop, OSC 7/133 capture, and the bridge
/// to SwiftTerm's headless `Terminal` engine here — never reaching into a
/// concrete terminal view.
///
/// Invariant (enforced by convention + the `app-shell` spec): XttyCore does not
/// import the app/UI target, and uses only SwiftTerm's headless engine, not its
/// `TerminalView`.
public enum XttyCore {
    /// Marker for the current skeleton milestone. Replaced with real surface
    /// area as engine work lands in subsequent milestones.
    public static let milestone = "P0: app skeleton"
}
