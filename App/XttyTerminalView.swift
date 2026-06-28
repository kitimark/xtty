import AppKit
import SwiftTerm
import XttyCore

/// Direction for pane focus navigation.
enum FocusDirection { case left, right, up, down }

/// Pane-scoped commands a focused `XttyTerminalView` forwards to its owner. The
/// view is the responder-chain target (design D3); it doesn't know the tree, so
/// it hands intent to the `PaneController`, which relays to the window controller.
@MainActor
protocol XttyTerminalViewCommands: AnyObject {
    func splitPane(axis: SplitAxis)
    func closePane()
    func moveFocus(_ direction: FocusDirection)
    func newTab()
    func newWindow()
    /// Spatial-block ops (P4b-2): scroll to the previous/next command prompt, and
    /// copy the focused/last command's output. No-op gracefully without anchors.
    func jumpToPrompt(_ direction: BlockNavigation.JumpDirection)
    func copyCommandOutput()
}

/// xtty's terminal view: SwiftTerm's `LocalProcessTerminalView` plus the
/// pane-scoped command handlers that ride the **responder chain**.
///
/// Pane-scoped menu commands are sent with `target: nil`, so AppKit routes them
/// to the key window's first responder — the focused pane's view. Handling them
/// here means "the active pane" is simply the first responder; no controller
/// tracks it for dispatch (design D3). Each handler forwards to `commands`.
///
/// **Why the `validateUserInterfaceItem` override:** SwiftTerm returns `false`
/// for any action it doesn't recognize (and logs it), which would disable our
/// custom items. We whitelist our selectors and defer the rest to `super`.
@MainActor
final class XttyTerminalView: LocalProcessTerminalView {
    /// The configured base font size; `resetFontSize` (Cmd 0) returns here.
    var configuredFontSize: CGFloat = CGFloat(XttyConfig.default.fontSize)

    /// The owner that fulfills pane-scoped commands (the `PaneController`).
    weak var commands: XttyTerminalViewCommands?

    /// Called when the engine switches between the normal and alternate screen
    /// buffers (passes `true` when now on the alternate screen). Drives OSC 133
    /// block suppression so full-screen apps (vim/htop) don't become blocks.
    var onBufferActivated: ((Bool) -> Void)?

    /// Smallest/largest live font sizes, to keep the grid legible and bounded.
    private static let fontSizeRange: ClosedRange<CGFloat> = 6...72

    // MARK: Font size (ephemeral; responder-chain routed)

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

    // MARK: Pane commands (responder-chain routed → commands owner)

    @objc func splitPaneRight(_ sender: Any?) { commands?.splitPane(axis: .row) }
    @objc func splitPaneDown(_ sender: Any?) { commands?.splitPane(axis: .column) }
    @objc func closePane(_ sender: Any?) { commands?.closePane() }
    @objc func focusPaneLeft(_ sender: Any?) { commands?.moveFocus(.left) }
    @objc func focusPaneRight(_ sender: Any?) { commands?.moveFocus(.right) }
    @objc func focusPaneUp(_ sender: Any?) { commands?.moveFocus(.up) }
    @objc func focusPaneDown(_ sender: Any?) { commands?.moveFocus(.down) }
    @objc func newTerminalTab(_ sender: Any?) { commands?.newTab() }
    @objc func newTerminalWindow(_ sender: Any?) { commands?.newWindow() }

    // MARK: Spatial-block commands (P4b-2; responder-chain routed → commands owner)

    @objc func jumpToPreviousPrompt(_ sender: Any?) { commands?.jumpToPrompt(.previous) }
    @objc func jumpToNextPrompt(_ sender: Any?) { commands?.jumpToPrompt(.next) }
    @objc func copyCommandOutput(_ sender: Any?) { commands?.copyCommandOutput() }

    // MARK: Alternate-screen detection

    /// SwiftTerm calls this (an `open` `TerminalDelegate` method on the view) on
    /// every normal⇄alternate buffer switch (DECSET/DECRST 47/1047/1049). Read the
    /// engine's public truth source to derive enter vs exit, then relay it.
    override func bufferActivated(source: Terminal) {
        super.bufferActivated(source: source)
        onBufferActivated?(source.isCurrentBufferAlternate)
    }

    // MARK: Menu validation

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {
        case #selector(increaseFontSize(_:)),
             #selector(decreaseFontSize(_:)),
             #selector(resetFontSize(_:)),
             #selector(splitPaneRight(_:)),
             #selector(splitPaneDown(_:)),
             #selector(closePane(_:)),
             #selector(focusPaneLeft(_:)),
             #selector(focusPaneRight(_:)),
             #selector(focusPaneUp(_:)),
             #selector(focusPaneDown(_:)),
             #selector(newTerminalTab(_:)),
             #selector(newTerminalWindow(_:)),
             #selector(jumpToPreviousPrompt(_:)),
             #selector(jumpToNextPrompt(_:)),
             #selector(copyCommandOutput(_:)):
            return true
        default:
            return super.validateUserInterfaceItem(item)
        }
    }
}
