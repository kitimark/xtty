import Foundation

/// The rendering backend for the terminal view: the default CoreGraphics path or
/// SwiftTerm's experimental Metal path.
///
/// A global (base-only) configuration value, parsed by `XttyConfigLoader` and
/// carried on `XttyConfigSet`. It is also used by the performance harness to A/B
/// the two renderers without rebuilding. View-free and `Sendable` so it stays in
/// the engine-facing seam.
public enum RendererBackend: String, Equatable, Sendable, CaseIterable, Codable {
    /// SwiftTerm's default CoreGraphics renderer.
    case coregraphics
    /// SwiftTerm's experimental Metal renderer (`setUseMetal(true)`).
    case metal
}
