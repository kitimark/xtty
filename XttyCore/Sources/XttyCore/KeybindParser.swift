import Foundation

/// Parses a chord string like `"cmd+shift+d"` or `"cmd+opt+left"` into a
/// `KeyChord`. Pure and view-free — the same primitive the P3b Quick-Terminal
/// global hotkey will reuse.
///
/// Grammar: `token ("+" token)*`, case-insensitive, whitespace-trimmed.
/// - modifiers: `cmd`/`command`, `ctrl`/`control`, `opt`/`option`/`alt`, `shift`
/// - keys: a single character (`d`, `0`, `[`, `-`), an arrow (`left`/`right`/
///   `up`/`down`), or a named symbol (`plus`, `minus`, `equal`, `space`) — `plus`
///   exists because `+` is the token delimiter.
///
/// Validation: exactly one non-modifier key **and** at least one modifier;
/// anything else returns `nil` (the caller falls back + warns — fail-soft).
public enum KeybindParser {
    public static func parse(_ string: String) -> KeyChord? {
        let tokens = ChordTokenizing.tokens(string)

        var modifiers: ModifierSet = []
        var key: KeyToken?

        for token in tokens {
            if token.isEmpty { return nil }  // e.g. "cmd++" or trailing "+"
            if let modifier = ChordTokenizing.modifier(for: token) {
                modifiers.insert(modifier)
            } else if let parsed = keyToken(for: token) {
                if key != nil { return nil }  // more than one non-modifier key
                key = parsed
            } else {
                return nil  // unknown token
            }
        }

        guard let key, !modifiers.isEmpty else { return nil }
        return KeyChord(key: key, modifiers: modifiers)
    }

    private static func keyToken(for token: String) -> KeyToken? {
        switch token {
        case "left": return .arrowLeft
        case "right": return .arrowRight
        case "up": return .arrowUp
        case "down": return .arrowDown
        case "plus": return .character("+")
        case "minus": return .character("-")
        case "equal": return .character("=")
        case "space": return .character(" ")
        default:
            if token.count == 1, let c = token.first { return .character(c) }
            return nil
        }
    }
}
