import AppKit
import SwiftTerm

/// A `TerminalViewDelegate` that intercepts **only** `requestOpenLink` and
/// forwards every other delegate method verbatim to the original delegate.
///
/// Why a proxy (add-file-link-open design D1): `LocalProcessTerminalView` installs
/// itself as the view's `terminalDelegate` and forwards a *curated subset* of
/// delegate calls to its `processDelegate` (the `PaneController`) — but
/// `requestOpenLink` is NOT in that set, so it falls through to SwiftTerm's
/// protocol-extension default (`NSWorkspace.open` on any scheme). That default
/// can't be overridden by a subclass (it satisfied the superclass's conformance
/// via static dispatch), and `mouseUp` is `public` not `open`. Installing this
/// proxy as `terminalDelegate` (a `public weak var`) lets xtty route link opens
/// — file:line → editor, plus the scheme guard — with **no SwiftTerm fork**.
///
/// KEEP IN SYNC: this forwards every `TerminalViewDelegate` method except
/// `requestOpenLink`. If SwiftTerm adds a delegate method, add a forward here, or
/// it will silently use the (often no-op) protocol-extension default — the e2e
/// suite (which types, resizes, and reads cwd) is the backstop for a dropped one.
final class LinkRoutingTerminalDelegate: NSObject, TerminalViewDelegate {
    /// The original delegate (the SwiftTerm view itself). Weak: the view owns the
    /// `PaneController` which owns this proxy; the view holds the proxy weakly.
    private weak var inner: TerminalViewDelegate?
    private let onOpenLink: (String, [String: String]) -> Void

    init(forwardingTo inner: TerminalViewDelegate,
         onOpenLink: @escaping (String, [String: String]) -> Void) {
        self.inner = inner
        self.onOpenLink = onOpenLink
    }

    // The one method we intercept.
    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
        onOpenLink(link, params)
    }

    // Everything else forwards verbatim to the original delegate.
    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        inner?.send(source: source, data: data)
    }
    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        inner?.sizeChanged(source: source, newCols: newCols, newRows: newRows)
    }
    func setTerminalTitle(source: TerminalView, title: String) {
        inner?.setTerminalTitle(source: source, title: title)
    }
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        inner?.hostCurrentDirectoryUpdate(source: source, directory: directory)
    }
    func scrolled(source: TerminalView, position: Double) {
        inner?.scrolled(source: source, position: position)
    }
    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {
        inner?.rangeChanged(source: source, startY: startY, endY: endY)
    }
    func bell(source: TerminalView) {
        inner?.bell(source: source)
    }
    func clipboardCopy(source: TerminalView, content: Data) {
        inner?.clipboardCopy(source: source, content: content)
    }
    func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {
        inner?.iTermContent(source: source, content: content)
    }
}
