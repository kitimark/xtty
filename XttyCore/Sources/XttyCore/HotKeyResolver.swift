import Foundation

/// Resolved Quick-Terminal settings from the user config. View-free and
/// testable; mirrors `KeybindResolver`. The two config keys live in this
/// capability (parsed from the same flat key/value map) and deliberately do not
/// enter `XttyConfig` / the `terminal-configuration` schema.
public struct QuickTerminalSettings: Equatable, Sendable {
    /// Whether the feature is enabled (the `quick-terminal` key).
    public let enabled: Bool
    /// The parsed global hotkey, or `nil` when unset/unparseable. The app
    /// registers a hotkey (and creates the panel) only when this is non-nil.
    public let hotKey: HotKeySpec?

    public init(enabled: Bool, hotKey: HotKeySpec?) {
        self.enabled = enabled
        self.hotKey = hotKey
    }

    /// The feature off: no panel, no hotkey.
    public static let disabled = QuickTerminalSettings(enabled: false, hotKey: nil)
}

/// Reads the quick-terminal keys (`quick-terminal`, `quick-terminal-hotkey`)
/// from parsed config pairs. Fail-soft (the config layer's posture): an enabled
/// feature with a missing or unparseable hotkey yields `hotKey == nil` and is
/// reported via `warn`, never aborting startup.
public enum HotKeyResolver {
    public static func resolve(
        from pairs: [String: String],
        warn: (String) -> Void = { _ in }
    ) -> QuickTerminalSettings {
        let enabled = pairs["quick-terminal"].flatMap(XttyConfigLoader.parseBool) ?? false
        guard enabled else { return .disabled }

        guard let raw = pairs["quick-terminal-hotkey"], !raw.isEmpty else {
            warn("quick-terminal is enabled but 'quick-terminal-hotkey' is unset; the quick terminal is disabled")
            return QuickTerminalSettings(enabled: true, hotKey: nil)
        }
        guard let spec = HotKeyParser.parse(raw) else {
            warn("quick-terminal-hotkey: '\(raw)' is not a valid hotkey; the quick terminal is disabled")
            return QuickTerminalSettings(enabled: true, hotKey: nil)
        }
        return QuickTerminalSettings(enabled: true, hotKey: spec)
    }
}
