import Foundation

/// A profile's launch overrides: how (and where) to start the pane's process,
/// distinct from its appearance (`XttyConfig`).
///
/// Toolkit-independent and `Sendable` so it stays in the view-free seam. A
/// `command` is run through the user's login + interactive shell (see
/// `ShellResolver.launchConfig(override:…)`), `cwd` sets the working directory,
/// and `env` is merged additively onto the seed environment (PATH excluded — the
/// login shell builds it, so the loader drops any `env-PATH`).
public struct LaunchOverride: Equatable, Sendable {
    /// A command line to run instead of a plain interactive login shell; `nil`
    /// launches the login shell. Run verbatim as a single `-c` argument.
    public var command: String?
    /// Working directory (already `~`/`$HOME`-expandable); `nil` uses the default.
    public var cwd: String?
    /// Additive environment (profile wins on conflict); never contains `PATH`.
    public var env: [String: String]

    public init(command: String? = nil, cwd: String? = nil, env: [String: String] = [:]) {
        self.command = command
        self.cwd = cwd
        self.env = env
    }

    /// No overrides — a plain login shell in the default directory.
    public static let none = LaunchOverride()
}

/// A named bundle of settings: resolved appearance (`config`) plus launch
/// overrides (`launch`). `name` is `nil` for the base profile (the lines before
/// the first `[profile "…"]` header), and the section name otherwise.
public struct XttyProfile: Equatable, Sendable {
    public let name: String?
    public let config: XttyConfig
    public let launch: LaunchOverride

    public init(name: String?, config: XttyConfig, launch: LaunchOverride = .none) {
        self.name = name
        self.config = config
        self.launch = launch
    }
}

/// The fully resolved configuration: the base profile, the named profiles, the
/// optional default-profile selection, and the global `confirm-close` behavior.
///
/// Produced by `XttyConfigLoader.resolveSet`. A config file with no profile
/// sections yields a set whose `base` equals the old flat resolution and whose
/// `profiles` is empty (backward-compatible by construction).
public struct XttyConfigSet: Equatable, Sendable {
    public let base: XttyProfile
    public let profiles: [String: XttyProfile]
    public let defaultProfileName: String?
    /// Whether to confirm closing a pane with a running foreground job (global,
    /// base-only). Defaults to `true`.
    public let confirmClose: Bool
    /// The git-review panel's default changed-files list layout (global, base-only).
    /// Defaults to `.flat` (the status-category grouping).
    public let gitReviewLayout: GitReviewLayout
    /// The terminal rendering backend (global, base-only). Defaults to
    /// `.coregraphics`; `.metal` opts into SwiftTerm's experimental Metal path.
    public let renderer: RendererBackend

    public init(
        base: XttyProfile,
        profiles: [String: XttyProfile] = [:],
        defaultProfileName: String? = nil,
        confirmClose: Bool = true,
        gitReviewLayout: GitReviewLayout = .flat,
        renderer: RendererBackend = .coregraphics
    ) {
        self.base = base
        self.profiles = profiles
        self.defaultProfileName = defaultProfileName
        self.confirmClose = confirmClose
        self.gitReviewLayout = gitReviewLayout
        self.renderer = renderer
    }

    /// The profile new sessions use: the `default-profile` if it resolves, else base.
    public var defaultProfile: XttyProfile {
        defaultProfileName.flatMap { profiles[$0] } ?? base
    }

    /// Look up a profile by name; an unknown or `nil` name yields the base profile.
    public func profile(named name: String?) -> XttyProfile {
        guard let name else { return base }
        return profiles[name] ?? base
    }

    /// The profile names, for building a selection menu (sorted for stable order).
    public var profileNames: [String] {
        profiles.keys.sorted()
    }
}
