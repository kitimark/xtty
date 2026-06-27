import AppKit
import XttyCore

/// Translates a toolkit-independent `KeyChord` (from `XttyCore`) into an
/// `NSMenuItem` key equivalent. This is the menu adapter half of design D9; the
/// P3b Quick-Terminal hotkey adds a Carbon adapter over the same `KeyChord`.
enum KeybindAdapter {
    /// The `keyEquivalent` string for a token. Arrows use AppKit's function-key
    /// unicode; characters are lowercased (Shift is carried in the modifier mask).
    static func keyEquivalent(for token: KeyToken) -> String {
        switch token {
        case .character(let c): return String(c).lowercased()
        case .arrowUp: return String(UnicodeScalar(NSUpArrowFunctionKey)!)
        case .arrowDown: return String(UnicodeScalar(NSDownArrowFunctionKey)!)
        case .arrowLeft: return String(UnicodeScalar(NSLeftArrowFunctionKey)!)
        case .arrowRight: return String(UnicodeScalar(NSRightArrowFunctionKey)!)
        }
    }

    static func modifierFlags(_ chord: KeyChord) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if chord.modifiers.contains(.command) { flags.insert(.command) }
        if chord.modifiers.contains(.shift) { flags.insert(.shift) }
        if chord.modifiers.contains(.option) { flags.insert(.option) }
        if chord.modifiers.contains(.control) { flags.insert(.control) }
        // Arrow keys are function keys; AppKit needs `.function` to match them.
        switch chord.key {
        case .arrowUp, .arrowDown, .arrowLeft, .arrowRight: flags.insert(.function)
        case .character: break
        }
        return flags
    }

    /// Apply a chord to a menu item. A nil chord (action unbound) leaves the item
    /// without a key equivalent.
    @MainActor
    static func apply(_ chord: KeyChord?, to item: NSMenuItem) {
        guard let chord else { return }
        item.keyEquivalent = keyEquivalent(for: chord.key)
        item.keyEquivalentModifierMask = modifierFlags(chord)
    }
}
