import Foundation

/// Shared lexing for chord strings like `"cmd+shift+d"`.
///
/// Both `KeybindParser` (menu key equivalents) and `HotKeyParser` (the global
/// Quick-Terminal hotkey) split on `+` and recognize the *same* modifier
/// vocabulary; keeping that here stops the two from drifting. They differ only
/// in how the single non-modifier key is mapped — a `KeyToken` character for
/// menus vs. a positional virtual keycode for the global hotkey.
enum ChordTokenizing {
    /// Split a chord into lowercased, whitespace-trimmed tokens. Empty
    /// subsequences are preserved so a stray `+` (e.g. `"cmd++"` or a trailing
    /// `"+"`) surfaces as an empty token the caller can reject.
    static func tokens(_ string: String) -> [String] {
        string.lowercased()
            .split(separator: "+", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// The modifier for a token, or `nil` if the token is not a modifier word.
    static func modifier(for token: String) -> ModifierSet? {
        switch token {
        case "cmd", "command": return .command
        case "ctrl", "control": return .control
        case "opt", "option", "alt": return .option
        case "shift": return .shift
        default: return nil
        }
    }
}
