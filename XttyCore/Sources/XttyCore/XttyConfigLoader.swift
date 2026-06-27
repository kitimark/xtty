import Foundation

/// Discovers, parses, and resolves the xtty config file into an `XttyConfig`.
///
/// All the logic is pure and view-free so it can be exercised by `swift test`
/// without launching the app or creating a terminal view. The file format is
/// Ghostty-style: line-oriented `key = value`, `#` comments, blank lines ignored,
/// whitespace trimmed. Unknown keys are ignored (forward-compatible); a recognized
/// key with an invalid value falls back to that key's default and is reported via
/// `warn`. A missing file yields all defaults.
public enum XttyConfigLoader {
    /// Hard ceiling on scrollback to keep memory bounded (product value M1).
    public static let scrollbackMax = 100_000
    /// Sane bounds for a configured font size; out-of-range values are clamped.
    public static let fontSizeRange: ClosedRange<Double> = 6...72

    // MARK: Parsing

    /// Parse raw config text into a key→value map. Later duplicate keys win.
    public static func parse(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            if !key.isEmpty { result[key] = value }
        }
        return result
    }

    // MARK: Resolution

    /// Resolve a typed config from parsed key/value pairs, applying defaults and
    /// per-key fallback. `warn` receives a message for each invalid value.
    public static func resolve(
        from pairs: [String: String],
        warn: (String) -> Void = { _ in }
    ) -> XttyConfig {
        var config = XttyConfig.default

        if let raw = pairs["font-family"] {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            config.fontFamily = trimmed.isEmpty ? nil : trimmed
        }

        if let raw = pairs["font-size"] {
            if let value = Double(raw) {
                config.fontSize = min(max(value, fontSizeRange.lowerBound), fontSizeRange.upperBound)
            } else {
                warn("font-size: '\(raw)' is not a number; using \(config.fontSize)")
            }
        }

        if let raw = pairs["theme"] {
            if let theme = TerminalTheme.named(raw) {
                config.themeName = theme.name
            } else {
                warn("theme: '\(raw)' is not a known theme; using '\(config.themeName)'")
            }
        }

        if let raw = pairs["scrollback"] {
            if let value = Int(raw), value >= 0 {
                config.scrollback = min(value, scrollbackMax)
            } else {
                warn("scrollback: '\(raw)' is not a non-negative integer; using \(config.scrollback)")
            }
        }

        if let raw = pairs["option-as-meta"] {
            if let value = parseBool(raw) {
                config.optionAsMeta = value
            } else {
                warn("option-as-meta: '\(raw)' is not a boolean; using \(config.optionAsMeta)")
            }
        }

        return config
    }

    /// Parse a permissive boolean (`true/false`, `yes/no`, `1/0`, `on/off`).
    static func parseBool(_ raw: String) -> Bool? {
        switch raw.lowercased() {
        case "true", "yes", "1", "on": return true
        case "false", "no", "0", "off": return false
        default: return nil
        }
    }

    // MARK: Discovery & loading

    /// The config file path: `$XDG_CONFIG_HOME/xtty/config` when `XDG_CONFIG_HOME`
    /// is set and non-empty, otherwise `<home>/.config/xtty/config`.
    public static func configPath(
        environment: [String: String],
        homeDirectory: String
    ) -> String {
        let base: String
        if let xdg = environment["XDG_CONFIG_HOME"], !xdg.isEmpty {
            base = xdg
        } else {
            base = (homeDirectory as NSString).appendingPathComponent(".config")
        }
        return (base as NSString).appendingPathComponent("xtty/config")
    }

    /// Load and resolve the config from disk. A missing/unreadable file yields
    /// `XttyConfig.default`. `warn` receives messages for invalid values.
    public static func load(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: String = NSHomeDirectory(),
        warn: (String) -> Void = { _ in }
    ) -> XttyConfig {
        let path = configPath(environment: environment, homeDirectory: homeDirectory)
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            return XttyConfig.default
        }
        return resolve(from: parse(text), warn: warn)
    }
}
