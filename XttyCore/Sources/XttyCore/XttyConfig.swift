import Foundation

/// A toolkit-independent RGB color (8 bits per channel).
///
/// `XttyCore` deliberately avoids AppKit (`NSColor`) and SwiftTerm color types so
/// the config layer stays portable and unit-testable with `swift test`. The app
/// layer converts these to whatever the renderer needs.
public struct RGB8: Equatable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(_ red: UInt8, _ green: UInt8, _ blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

/// A terminal color theme: 16 ANSI colors plus foreground/background/cursor.
public struct TerminalTheme: Equatable, Sendable {
    public let name: String
    /// Exactly 16 entries (ANSI 0–7 normal, 8–15 bright).
    public let ansi: [RGB8]
    public let foreground: RGB8
    public let background: RGB8
    public let cursor: RGB8

    public init(name: String, ansi: [RGB8], foreground: RGB8, background: RGB8, cursor: RGB8) {
        self.name = name
        self.ansi = ansi
        self.foreground = foreground
        self.background = background
        self.cursor = cursor
    }

    /// The standard xterm 16-color ANSI palette, shared by the built-in themes.
    private static let standardAnsi: [RGB8] = [
        RGB8(0, 0, 0),        // 0 black
        RGB8(205, 0, 0),      // 1 red
        RGB8(0, 205, 0),      // 2 green
        RGB8(205, 205, 0),    // 3 yellow
        RGB8(0, 0, 238),      // 4 blue
        RGB8(205, 0, 205),    // 5 magenta
        RGB8(0, 205, 205),    // 6 cyan
        RGB8(229, 229, 229),  // 7 white
        RGB8(127, 127, 127),  // 8 bright black
        RGB8(255, 0, 0),      // 9 bright red
        RGB8(0, 255, 0),      // 10 bright green
        RGB8(255, 255, 0),    // 11 bright yellow
        RGB8(92, 92, 255),    // 12 bright blue
        RGB8(255, 0, 255),    // 13 bright magenta
        RGB8(0, 255, 255),    // 14 bright cyan
        RGB8(255, 255, 255),  // 15 bright white
    ]

    /// xtty's default dark theme.
    public static let dark = TerminalTheme(
        name: "dark",
        ansi: standardAnsi,
        foreground: RGB8(0xc5, 0xc8, 0xc6),
        background: RGB8(0x1d, 0x1f, 0x21),
        cursor: RGB8(0xc5, 0xc8, 0xc6)
    )

    /// A light theme for bright environments.
    public static let light = TerminalTheme(
        name: "light",
        ansi: standardAnsi,
        foreground: RGB8(0x1d, 0x1f, 0x21),
        background: RGB8(0xff, 0xff, 0xff),
        cursor: RGB8(0x1d, 0x1f, 0x21)
    )

    /// The theme used when none is configured or a name is unknown.
    public static let defaultTheme = dark

    /// All built-in themes by name.
    public static let builtIns: [TerminalTheme] = [dark, light]

    /// Look up a built-in theme by name (case-insensitive); nil if unknown.
    public static func named(_ name: String) -> TerminalTheme? {
        let lower = name.lowercased()
        return builtIns.first { $0.name == lower }
    }
}

/// The resolved xtty configuration — typed, defaulted, and toolkit-independent.
///
/// Produced by `XttyConfigLoader` from the user's `~/.config/xtty/config`. The
/// app layer maps this onto the terminal (font, palette, scrollback, option key).
public struct XttyConfig: Equatable, Sendable {
    /// Preferred font family; `nil` means "use the app's monospaced default".
    public var fontFamily: String?
    /// Base font point size.
    public var fontSize: Double
    /// Name of the (built-in) theme to use.
    public var themeName: String
    /// Scrollback retention in lines (bounded; product value M1).
    public var scrollback: Int
    /// Whether the Option key sends Meta (vs. typing composed characters).
    public var optionAsMeta: Bool
    /// Command template for opening clicked file links (`${file}`/`${line}`/
    /// `${column}` tokens). `nil` means "infer from `$VISUAL`/`$EDITOR`, else
    /// macOS `open`" (see `LinkRouter`).
    public var linkOpener: String?
    /// Number of unified-diff context lines shown in the git-review panel
    /// (`git diff --unified=N`). Non-negative; default 3 (git's own default).
    public var diffContext: Int

    public init(fontFamily: String?, fontSize: Double, themeName: String, scrollback: Int, optionAsMeta: Bool, linkOpener: String? = nil, diffContext: Int = 3) {
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.themeName = themeName
        self.scrollback = scrollback
        self.optionAsMeta = optionAsMeta
        self.linkOpener = linkOpener
        self.diffContext = diffContext
    }

    /// The built-in defaults used for a missing file or any invalid value.
    public static let `default` = XttyConfig(
        fontFamily: nil,
        fontSize: 13,
        themeName: TerminalTheme.defaultTheme.name,
        scrollback: 10_000,
        optionAsMeta: true
    )

    /// The resolved theme for `themeName` (falls back to the default theme).
    public var theme: TerminalTheme {
        TerminalTheme.named(themeName) ?? TerminalTheme.defaultTheme
    }
}
