import AppKit
import SwiftTerm
import XttyCore

/// Maps a resolved `XttyConfig` (toolkit-independent) onto SwiftTerm's terminal
/// view: font, theme palette, scrollback cap, and option-as-meta.
///
/// This is the app-side adapter for the `XttyCore` config seam — it holds the
/// AppKit/SwiftTerm knowledge (`NSFont`, `SwiftTerm.Color`, `NSColor`) that
/// `XttyCore` intentionally avoids, so the core stays portable + unit-testable.
enum TerminalConfigurator {
    /// Build the terminal font from config: the configured family at the
    /// configured size, falling back to the monospaced system font.
    static func makeFont(_ config: XttyConfig) -> NSFont {
        let size = CGFloat(config.fontSize)
        if let family = config.fontFamily, let font = NSFont(name: family, size: size) {
            return font
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    /// Apply the full configuration to a live terminal view. Safe to call after
    /// the view exists; scrollback is changed on the engine via the core seam.
    @MainActor
    static func apply(_ config: XttyConfig, to view: LocalProcessTerminalView) {
        view.font = makeFont(config)

        let theme = config.theme
        view.installColors(theme.ansi.map(swiftTermColor))
        view.nativeBackgroundColor = nsColor(theme.background)
        view.nativeForegroundColor = nsColor(theme.foreground)
        view.caretColor = nsColor(theme.cursor)

        // Bounded scrollback (product value M1). The engine retains at most this
        // many history lines on the normal buffer.
        view.getTerminal().changeScrollback(config.scrollback)

        view.optionAsMetaKey = config.optionAsMeta
    }

    // MARK: Color conversion

    /// `RGB8` (8-bit) → SwiftTerm `Color` (16-bit channels).
    private static func swiftTermColor(_ c: RGB8) -> SwiftTerm.Color {
        SwiftTerm.Color(red: UInt16(c.red) * 257,
                        green: UInt16(c.green) * 257,
                        blue: UInt16(c.blue) * 257)
    }

    /// `RGB8` (8-bit) → `NSColor` (sRGB).
    private static func nsColor(_ c: RGB8) -> NSColor {
        NSColor(srgbRed: CGFloat(c.red) / 255,
                green: CGFloat(c.green) / 255,
                blue: CGFloat(c.blue) / 255,
                alpha: 1)
    }
}
