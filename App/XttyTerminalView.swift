import AppKit
import SwiftTerm
import XttyCore

/// xtty's terminal view: SwiftTerm's `LocalProcessTerminalView` plus the
/// pane-scoped command handlers that ride the **responder chain**.
///
/// Pane-scoped menu commands (font size now; split/close/focus arrive in later
/// layers) are sent with `target: nil`, so AppKit routes them to the key
/// window's first responder — which is the focused pane's view. Handling them
/// here means "the active pane" is simply the first responder; no controller
/// tracks it for dispatch (design D3).
///
/// **Why the `validateUserInterfaceItem` override:** SwiftTerm's implementation
/// returns `false` for any action it doesn't recognize (and logs it), which would
/// leave our custom menu items disabled. We whitelist our selectors and defer the
/// rest to `super`.
@MainActor
final class XttyTerminalView: LocalProcessTerminalView {
    /// The configured base font size; `resetFontSize` (Cmd 0) returns here.
    /// Set by the owning `PaneController` from the resolved config at creation.
    var configuredFontSize: CGFloat = CGFloat(XttyConfig.default.fontSize)

    /// Smallest/largest live font sizes, to keep the grid legible and bounded.
    private static let fontSizeRange: ClosedRange<CGFloat> = 6...72

    // MARK: Font size (ephemeral; not persisted to config — P2 policy)

    @objc func increaseFontSize(_ sender: Any?) { adjustFontSize(by: +1) }
    @objc func decreaseFontSize(_ sender: Any?) { adjustFontSize(by: -1) }

    @objc func resetFontSize(_ sender: Any?) {
        guard font.pointSize != configuredFontSize,
              let reset = NSFont(descriptor: font.fontDescriptor, size: configuredFontSize)
        else { return }
        font = reset
    }

    private func adjustFontSize(by delta: CGFloat) {
        let newSize = min(max(font.pointSize + delta, Self.fontSizeRange.lowerBound),
                          Self.fontSizeRange.upperBound)
        guard newSize != font.pointSize,
              let resized = NSFont(descriptor: font.fontDescriptor, size: newSize)
        else { return }
        font = resized
    }

    // MARK: Menu validation

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {
        case #selector(increaseFontSize(_:)),
             #selector(decreaseFontSize(_:)),
             #selector(resetFontSize(_:)):
            return true
        default:
            return super.validateUserInterfaceItem(item)
        }
    }
}
