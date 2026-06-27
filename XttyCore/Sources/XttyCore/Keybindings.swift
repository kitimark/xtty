import Foundation

/// A built-in keybinding preset. `iterm` is the default; `ghostty` matches
/// Ghostty's pane-focus convention for easy migration.
public enum KeybindStyle: String, CaseIterable, Sendable {
    case iterm
    case ghostty
}

/// The resolved action → chord map: a preset overlaid with per-action overrides.
public struct Keybindings: Sendable {
    public let map: [KeyAction: KeyChord]

    public init(map: [KeyAction: KeyChord]) { self.map = map }

    public func chord(for action: KeyAction) -> KeyChord? { map[action] }

    // MARK: Presets

    private static func cmd(_ c: Character) -> KeyChord { KeyChord(key: .character(c), modifiers: [.command]) }
    private static func cmdShift(_ c: Character) -> KeyChord { KeyChord(key: .character(c), modifiers: [.command, .shift]) }
    private static func cmdOpt(_ token: KeyToken) -> KeyChord { KeyChord(key: token, modifiers: [.command, .option]) }

    /// Bindings shared by every preset (splits, tabs/windows, close, font, find).
    private static var common: [KeyAction: KeyChord] {
        [
            .splitRight: cmd("d"),
            .splitDown: cmdShift("d"),
            .newTab: cmd("t"),
            .newWindow: cmd("n"),
            .close: cmd("w"),
            .fontIncrease: cmd("+"),
            .fontDecrease: cmd("-"),
            .fontReset: cmd("0"),
            .find: cmd("f"),
        ]
    }

    /// The action → chord map for a preset. Presets differ only in pane focus.
    public static func preset(_ style: KeybindStyle) -> [KeyAction: KeyChord] {
        var map = common
        switch style {
        case .iterm:
            map[.focusLeft] = cmdOpt(.arrowLeft)
            map[.focusRight] = cmdOpt(.arrowRight)
            map[.focusUp] = cmdOpt(.arrowUp)
            map[.focusDown] = cmdOpt(.arrowDown)
        case .ghostty:
            // Ghostty's prev/next pane on Cmd+[ / Cmd+]; up/down keep Cmd+Opt+arrows.
            map[.focusLeft] = cmd("[")
            map[.focusRight] = cmd("]")
            map[.focusUp] = cmdOpt(.arrowUp)
            map[.focusDown] = cmdOpt(.arrowDown)
        }
        return map
    }

    /// Resolve a preset plus per-action overrides (an override replaces just that
    /// action's chord; all others keep the preset's).
    public static func resolve(style: KeybindStyle, overrides: [KeyAction: KeyChord]) -> Keybindings {
        var map = preset(style)
        for (action, chord) in overrides { map[action] = chord }
        return Keybindings(map: map)
    }
}

/// Resolves `Keybindings` from parsed config pairs (the `keybind-*` keys). Lives
/// in the `terminal-keybindings` capability; P2's `terminal-configuration` schema
/// is untouched. Fail-soft, matching the config posture.
public enum KeybindResolver {
    public static func resolve(
        from pairs: [String: String],
        warn: (String) -> Void = { _ in }
    ) -> Keybindings {
        var style = KeybindStyle.iterm
        if let raw = pairs["keybind-style"] {
            if let parsed = KeybindStyle(rawValue: raw.lowercased()) {
                style = parsed
            } else {
                warn("keybind-style: '\(raw)' is not a known style; using '\(style.rawValue)'")
            }
        }

        var overrides: [KeyAction: KeyChord] = [:]
        for action in KeyAction.allCases {
            let key = "keybind-" + action.rawValue
            guard let raw = pairs[key] else { continue }
            if let chord = KeybindParser.parse(raw) {
                overrides[action] = chord
            } else {
                warn("\(key): '\(raw)' is not a valid chord; keeping the preset binding")
            }
        }

        return Keybindings.resolve(style: style, overrides: overrides)
    }
}
