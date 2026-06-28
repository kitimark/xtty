import Foundation

/// A bindable command. The `rawValue` is the config-key suffix, e.g.
/// `keybind-split-right` binds `.splitRight`.
public enum KeyAction: String, CaseIterable, Sendable {
    case splitRight = "split-right"
    case splitDown = "split-down"
    case focusLeft = "focus-left"
    case focusRight = "focus-right"
    case focusUp = "focus-up"
    case focusDown = "focus-down"
    case newTab = "new-tab"
    case newWindow = "new-window"
    case close = "close"
    case fontIncrease = "font-increase"
    case fontDecrease = "font-decrease"
    case fontReset = "font-reset"
    case find = "find"
    case jumpPrevPrompt = "jump-prev-prompt"
    case jumpNextPrompt = "jump-next-prompt"
    case copyCommandOutput = "copy-command-output"
}

/// Toolkit-independent modifier keys. The app layer maps these to
/// `NSEvent.ModifierFlags` (menus) and, later, Carbon masks (the P3b global
/// hotkey) — one model, two adapters.
public struct ModifierSet: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let command = ModifierSet(rawValue: 1 << 0)
    public static let shift   = ModifierSet(rawValue: 1 << 1)
    public static let option  = ModifierSet(rawValue: 1 << 2)
    public static let control = ModifierSet(rawValue: 1 << 3)
}

/// The non-modifier key of a chord. Toolkit-independent: a character (letter,
/// digit, punctuation) or a named special key. Only what P3a needs is modeled;
/// P3b's Quick-Terminal hotkey extends this (space, grave, F-keys, …).
public enum KeyToken: Hashable, Sendable {
    case character(Character)
    case arrowUp
    case arrowDown
    case arrowLeft
    case arrowRight
}

/// A resolved keybinding: one non-modifier key plus its modifiers. A valid chord
/// always has ≥1 modifier (a bare key would hijack normal typing/the system).
public struct KeyChord: Hashable, Sendable {
    public let key: KeyToken
    public let modifiers: ModifierSet

    public init(key: KeyToken, modifiers: ModifierSet) {
        self.key = key
        self.modifiers = modifiers
    }
}
