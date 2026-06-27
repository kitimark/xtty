import Foundation

/// A toolkit-independent specification of a global hotkey: a *positional*
/// virtual key code (the physical key, layout-independent), its modifiers, and a
/// human-readable display string.
///
/// `virtualKeyCode` holds the macOS `kVK_*` value (e.g. `kVK_ANSI_Grave = 0x32`).
/// These are stable hardware key codes, so we store the integers directly and
/// `XttyCore` needs no Carbon import. The app layer maps `modifiers` to a Carbon
/// modifier mask and hands `virtualKeyCode` straight to `RegisterEventHotKey` —
/// the same "one model, two adapters" split `ModifierSet` already uses for menus.
public struct HotKeySpec: Equatable, Sendable {
    public let virtualKeyCode: UInt32
    public let modifiers: ModifierSet
    public let display: String

    public init(virtualKeyCode: UInt32, modifiers: ModifierSet, display: String) {
        self.virtualKeyCode = virtualKeyCode
        self.modifiers = modifiers
        self.display = display
    }
}

/// Parses a global-hotkey string like `"cmd+grave"` or `"ctrl+opt+t"` into a
/// `HotKeySpec`. Pure and view-free — the global-hotkey sibling of
/// `KeybindParser`, sharing its modifier vocabulary via `ChordTokenizing`.
///
/// Unlike `KeybindParser` (which yields a character-based `KeyToken` for menu key
/// equivalents), this maps the key to a **positional** virtual keycode: a global
/// hotkey binds a physical key regardless of layout, and `RegisterEventHotKey`
/// takes a `kVK_*` code. Validation matches the keybind rule: **≥1 modifier and
/// exactly 1 non-modifier key**; anything else returns `nil` (the caller warns +
/// disables — fail-soft). `fn` is not a Carbon modifier, so a chord using it
/// fails to parse and is rejected.
public enum HotKeyParser {
    public static func parse(_ string: String) -> HotKeySpec? {
        let tokens = ChordTokenizing.tokens(string)

        var modifiers: ModifierSet = []
        var keyName: String?

        for token in tokens {
            if token.isEmpty { return nil }  // stray "+" / trailing "+"
            if let modifier = ChordTokenizing.modifier(for: token) {
                modifiers.insert(modifier)
            } else {
                if keyName != nil { return nil }  // more than one non-modifier key
                keyName = token
            }
        }

        guard let keyName, !modifiers.isEmpty else { return nil }
        guard let keyCode = virtualKeyCode(for: keyName) else { return nil }
        return HotKeySpec(
            virtualKeyCode: keyCode,
            modifiers: modifiers,
            display: displayString(modifiers: modifiers, keyName: keyName)
        )
    }

    // MARK: Key name → virtual keycode

    /// Resolve a key name to its macOS virtual keycode: a named key (`grave`,
    /// `space`, arrows, `f1`…`f12`, …) or a single character (letter, digit, or
    /// punctuation). `nil` for anything unrecognized.
    static func virtualKeyCode(for name: String) -> UInt32? {
        if let named = namedKeyCodes[name] { return named }
        if name.count == 1, let c = name.first, let code = characterKeyCodes[c] { return code }
        return nil
    }

    /// Named keys → `kVK_*` codes.
    private static let namedKeyCodes: [String: UInt32] = [
        "grave": 0x32,
        "space": 0x31,
        "tab": 0x30,
        "return": 0x24, "enter": 0x24,
        "escape": 0x35, "esc": 0x35,
        "delete": 0x33, "backspace": 0x33,
        "forwarddelete": 0x75,
        "left": 0x7B, "right": 0x7C, "down": 0x7D, "up": 0x7E,
        "home": 0x73, "end": 0x77, "pageup": 0x74, "pagedown": 0x79,
        "minus": 0x1B, "equal": 0x18,
        "f1": 0x7A, "f2": 0x78, "f3": 0x63, "f4": 0x76,
        "f5": 0x60, "f6": 0x61, "f7": 0x62, "f8": 0x64,
        "f9": 0x65, "f10": 0x6D, "f11": 0x67, "f12": 0x6F,
    ]

    /// Single characters → `kVK_ANSI_*` codes (US-ANSI positions).
    private static let characterKeyCodes: [Character: UInt32] = [
        "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02, "e": 0x0E, "f": 0x03,
        "g": 0x05, "h": 0x04, "i": 0x22, "j": 0x26, "k": 0x28, "l": 0x25,
        "m": 0x2E, "n": 0x2D, "o": 0x1F, "p": 0x23, "q": 0x0C, "r": 0x0F,
        "s": 0x01, "t": 0x11, "u": 0x20, "v": 0x09, "w": 0x0D, "x": 0x07,
        "y": 0x10, "z": 0x06,
        "0": 0x1D, "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15,
        "5": 0x17, "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19,
        "-": 0x1B, "=": 0x18, "[": 0x21, "]": 0x1E, ";": 0x29,
        "'": 0x27, ",": 0x2B, ".": 0x2F, "/": 0x2C, "\\": 0x2A, "`": 0x32,
    ]

    // MARK: Display

    /// A human-readable chord, e.g. `cmd+grave` → `⌘\`` (modifiers in the
    /// conventional macOS order ⌃⌥⇧⌘). Used for logging and the menu title.
    private static func displayString(modifiers: ModifierSet, keyName: String) -> String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option) { s += "⌥" }
        if modifiers.contains(.shift) { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        s += keyDisplay(keyName)
        return s
    }

    private static func keyDisplay(_ name: String) -> String {
        switch name {
        case "grave", "`": return "`"
        case "space": return "Space"
        case "tab": return "⇥"
        case "return", "enter": return "↩"
        case "escape", "esc": return "⎋"
        case "delete", "backspace": return "⌫"
        case "left": return "←"
        case "right": return "→"
        case "up": return "↑"
        case "down": return "↓"
        case "minus": return "-"
        case "equal": return "="
        default: return name.uppercased()
        }
    }
}
