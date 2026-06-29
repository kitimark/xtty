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

    // MARK: Sectioned parsing (profiles)

    /// Pre-compiled `[profile "name"]` header matcher (the only valid header form).
    private static let profileHeader = try? NSRegularExpression(pattern: #"^\[profile\s+"([^"]+)"\]$"#)

    /// Parse config text into a base section plus named profile sections.
    ///
    /// Lines before the first `[profile "name"]` header form the **base**; each
    /// header begins a named block. Unlike `parse`, keys keep the original case of
    /// the `<NAME>` in `env-<NAME>` (env-var names are case-sensitive); all other
    /// keys are lowercased so recognized keys still match case-insensitively. A
    /// malformed/unquoted/empty profile header (or any other bracketed section
    /// type) is reported via `warn` and its lines are skipped, without aborting —
    /// so a typo never silently lands keys in the wrong profile. A file with no
    /// headers yields the base section only (and `profiles` empty).
    public static func parseSections(
        _ text: String,
        warn: (String) -> Void = { _ in }
    ) -> (base: [String: String], profiles: [(name: String, pairs: [String: String])]) {
        var base: [String: String] = [:]
        var profiles: [(name: String, pairs: [String: String])] = []
        // Where the current line's key lands: base, a profile index, or skip
        // (a malformed/unknown section whose keys are intentionally dropped).
        enum Target { case base; case profile(Int); case skip }
        var current: Target = .base

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            if line.hasPrefix("[") {
                if let profileHeader,
                   let match = profileHeader.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                   let nameRange = Range(match.range(at: 1), in: line) {
                    let name = String(line[nameRange])
                    if let idx = profiles.firstIndex(where: { $0.name == name }) {
                        warn("profile '\(name)' is defined more than once; later keys win")
                        current = .profile(idx)
                    } else {
                        profiles.append((name: name, pairs: [:]))
                        current = .profile(profiles.count - 1)
                    }
                } else {
                    if line.lowercased().hasPrefix("[profile") {
                        warn("malformed profile header \(line); expected [profile \"name\"] — skipping")
                    }
                    current = .skip
                }
                continue
            }

            guard let eq = line.firstIndex(of: "=") else { continue }
            let rawKey = line[..<eq].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            guard !rawKey.isEmpty else { continue }
            let key = normalizedKey(rawKey)

            switch current {
            case .base: base[key] = value
            case .profile(let i): profiles[i].pairs[key] = value
            case .skip: break
            }
        }
        return (base, profiles)
    }

    /// Lowercase a config key, preserving the original case of the `<NAME>` in an
    /// `env-<NAME>` key (environment-variable names are case-sensitive).
    static func normalizedKey(_ rawKey: String) -> String {
        if rawKey.lowercased().hasPrefix("env-") {
            // Keep everything after the `env-` prefix verbatim.
            let nameStart = rawKey.index(rawKey.startIndex, offsetBy: 4)
            return "env-" + rawKey[nameStart...]
        }
        return rawKey.lowercased()
    }

    // MARK: Resolution

    /// Resolve a typed config from parsed key/value pairs, applying defaults and
    /// per-key fallback. `warn` receives a message for each invalid value.
    public static func resolve(
        from pairs: [String: String],
        base: XttyConfig = .default,
        warn: (String) -> Void = { _ in }
    ) -> XttyConfig {
        var config = base

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

        if let raw = pairs["link-opener"] {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            config.linkOpener = trimmed.isEmpty ? nil : trimmed
        }

        if let raw = pairs["diff-context"] {
            if let value = Int(raw), value >= 0 {
                config.diffContext = value
            } else {
                warn("diff-context: '\(raw)' is not a non-negative integer; using \(config.diffContext)")
            }
        }

        return config
    }

    /// Resolve a full configuration **set** (base + named profiles + default
    /// selection + `confirm-close`) from raw config text. The base profile feeds
    /// the existing per-key resolution unchanged, so a file with no `[profile …]`
    /// headers yields `base == resolve(from: parse(text))` and an empty
    /// `profiles` map (backward-compatible by construction). Each named profile
    /// inherits the base appearance (`resolve(from:base:)`) and carries its own
    /// launch override. `default-profile`/`confirm-close` are honored base-only.
    public static func resolveSet(
        from text: String,
        warn: (String) -> Void = { _ in }
    ) -> XttyConfigSet {
        let (basePairs, profilePairs) = parseSections(text, warn: warn)

        let baseConfig = resolve(from: basePairs, warn: warn)
        let base = XttyProfile(name: nil, config: baseConfig, launch: launchOverride(from: basePairs, warn: warn))

        var profiles: [String: XttyProfile] = [:]
        for (name, pairs) in profilePairs {
            if pairs["default-profile"] != nil {
                warn("default-profile is ignored inside profile '\(name)' (it is base-only)")
            }
            if pairs["confirm-close"] != nil {
                warn("confirm-close is ignored inside profile '\(name)' (it is base-only)")
            }
            if pairs["git-review-layout"] != nil {
                warn("git-review-layout is ignored inside profile '\(name)' (it is base-only)")
            }
            if pairs["renderer"] != nil {
                warn("renderer is ignored inside profile '\(name)' (it is base-only)")
            }
            let config = resolve(from: pairs, base: baseConfig, warn: warn)
            profiles[name] = XttyProfile(name: name, config: config, launch: launchOverride(from: pairs, warn: warn))
        }

        var defaultProfileName: String? = nil
        if let raw = basePairs["default-profile"] {
            if profiles[raw] != nil {
                defaultProfileName = raw
            } else {
                warn("default-profile: '\(raw)' is not a defined profile; using base")
            }
        }

        var confirmClose = true
        if let raw = basePairs["confirm-close"] {
            if let value = parseBool(raw) {
                confirmClose = value
            } else {
                warn("confirm-close: '\(raw)' is not a boolean; using \(confirmClose)")
            }
        }

        var gitReviewLayout: GitReviewLayout = .flat
        if let raw = basePairs["git-review-layout"] {
            if let value = GitReviewLayout(rawValue: raw.lowercased()) {
                gitReviewLayout = value
            } else {
                warn("git-review-layout: '\(raw)' is not 'flat' or 'tree'; using \(gitReviewLayout.rawValue)")
            }
        }

        var renderer: RendererBackend = .coregraphics
        if let raw = basePairs["renderer"] {
            if let value = RendererBackend(rawValue: raw.lowercased()) {
                renderer = value
            } else {
                warn("renderer: '\(raw)' is not 'coregraphics' or 'metal'; using \(renderer.rawValue)")
            }
        }

        return XttyConfigSet(
            base: base,
            profiles: profiles,
            defaultProfileName: defaultProfileName,
            confirmClose: confirmClose,
            gitReviewLayout: gitReviewLayout,
            renderer: renderer
        )
    }

    /// Extract the launch override (`command`, `cwd`, `env-<NAME>`) from a
    /// profile's pairs. `env-PATH` is dropped with a warning (the login shell
    /// builds PATH); empty env names are skipped.
    static func launchOverride(
        from pairs: [String: String],
        warn: (String) -> Void = { _ in }
    ) -> LaunchOverride {
        let command = pairs["command"].flatMap { $0.isEmpty ? nil : $0 }
        let cwd = pairs["cwd"].flatMap { $0.isEmpty ? nil : $0 }

        var env: [String: String] = [:]
        for (key, value) in pairs where key.hasPrefix("env-") {
            let name = String(key.dropFirst(4))
            if name.isEmpty { continue }
            if name.uppercased() == "PATH" {
                warn("env-PATH is ignored; the login shell builds PATH")
                continue
            }
            env[name] = value
        }

        return LaunchOverride(command: command, cwd: cwd, env: env)
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
