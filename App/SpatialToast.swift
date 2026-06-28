import AppKit

/// A transient, non-modal confirmation overlay (P4b-2) — e.g. "Copied output".
///
/// Used as the fork-free substitute for a visual on-screen selection (design D7):
/// copy-command-output is engine-only, so this briefly tells the user what was
/// grabbed. It is purely cosmetic — it never takes focus, never blocks input
/// (the label ignores hit-testing), and auto-dismisses with a fade.
@MainActor
enum SpatialToast {
    /// Show `message` centered near the bottom of `host`'s window, fading out.
    static func show(_ message: String, over host: NSView) {
        guard let parent = host.window?.contentView else { return }

        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        let bubble = NSView()
        bubble.translatesAutoresizingMaskIntoConstraints = false
        bubble.wantsLayer = true
        bubble.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.78).cgColor
        bubble.layer?.cornerRadius = 8
        // Cosmetic only: pass clicks/keys straight through to the terminal.
        bubble.addSubview(label)

        let container = PassthroughView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(bubble)
        parent.addSubview(container, positioned: .above, relativeTo: nil)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            container.topAnchor.constraint(equalTo: parent.topAnchor),
            container.bottomAnchor.constraint(equalTo: parent.bottomAnchor),

            bubble.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            bubble.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -28),

            label.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 7),
            label.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -7),
        ])

        // Brief hold, then fade out and remove.
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            container.animator().alphaValue = 1
        }, completionHandler: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = 0.35
                    container.animator().alphaValue = 0
                }, completionHandler: { container.removeFromSuperview() })
            }
        })
    }

    /// A container that never intercepts mouse events (so the toast can't block
    /// the terminal beneath it).
    private final class PassthroughView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
