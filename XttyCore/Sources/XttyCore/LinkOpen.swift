import Foundation

/// Routing of clicked terminal links to a file editor or the system URL handler —
/// the view-free half of P4b-1 (`add-file-link-open`).
///
/// SwiftTerm detects links (URLs and file paths) and hands the string to xtty's
/// `requestOpenLink` interceptor; everything here is pure so it can be exercised
/// by `swift test` without launching the app or creating a terminal view. The app
/// layer performs only the AppKit-bound side effect (`NSWorkspace`/`Process`).
///
/// Pipeline: `classify` → scheme guard → resolve a file path against the live cwd
/// → build the opener invocation. `LinkRouter.resolve` composes all four.

// MARK: - Classification

/// A clicked link classified as either a scheme-bearing URL or a file reference.
public enum LinkTarget: Equatable, Sendable {
    /// A URL with an explicit scheme (lowercased), plus the original string.
    case url(scheme: String, raw: String)
    /// A file reference with an optional `:line[:column]` suffix.
    case file(path: String, line: Int?, column: Int?)
}

/// How the app should actually open a resolved target.
public enum OpenerInvocation: Equatable, Sendable {
    /// Launch an editor. `argv[0]` is the editor binary (the app resolves it on
    /// the user's PATH); the remaining elements are passed literally — the file
    /// path is a discrete argument and is never interpreted by a shell.
    case editorArgv([String])
    /// Open a file with the macOS default app via `/usr/bin/open` (no line jump).
    case systemOpenFile(String)
    /// Hand a URL to the system handler (`NSWorkspace`).
    case openURL(String)
}

/// The outcome of routing a clicked link.
public enum LinkOpenResolution: Equatable, Sendable {
    /// The link resolved to an actionable target (the `file` path is absolute).
    case open(target: LinkTarget, invocation: OpenerInvocation)
    /// A URL whose scheme the guard does not permit; not opened.
    case blocked(scheme: String)
    /// A file reference that could not be resolved (e.g. a relative path with no
    /// local working directory, such as over ssh); a no-op.
    case unresolved(reason: String)
}

/// Splits a string into a `(scheme://|known-scheme:)` URL or a `path[:line[:col]]`
/// file reference. Pure string logic — no disk access.
public enum LinkClassifier {
    /// URL schemes that have no `//` authority but are still URLs (so the guard
    /// can decide whether to open them).
    private static let bareSchemes: Set<String> = ["mailto", "tel", "sms"]

    public static func classify(_ link: String) -> LinkTarget {
        let trimmed = link.trimmingCharacters(in: .whitespaces)

        // file: URLs become file references; other schemes stay URLs.
        if let scheme = authorityScheme(of: trimmed) {
            if scheme == "file" {
                let (path, line, col) = splitLineColumn(filePath(fromFileURL: trimmed))
                return .file(path: path, line: line, column: col)
            }
            return .url(scheme: scheme, raw: trimmed)
        }
        if let scheme = bareScheme(of: trimmed) {
            return .url(scheme: scheme, raw: trimmed)
        }
        if trimmed.lowercased().hasPrefix("file:") {
            let rest = String(trimmed.dropFirst("file:".count))
            let (path, line, col) = splitLineColumn(filePath(fromRawPath: rest))
            return .file(path: path, line: line, column: col)
        }

        let (path, line, col) = splitLineColumn(trimmed)
        return .file(path: path, line: line, column: col)
    }

    /// The scheme of a `scheme://…` URL (lowercased), else `nil`. Requires the
    /// `//` authority so a bare `foo.swift:42` is NOT read as scheme `foo.swift`.
    private static func authorityScheme(of s: String) -> String? {
        guard let r = s.range(of: #"^[a-zA-Z][a-zA-Z0-9+.\-]*://"#, options: .regularExpression)
        else { return nil }
        return String(s[r.lowerBound..<s.index(s[r].endIndex, offsetBy: -3)]).lowercased()
    }

    /// The scheme of a known no-authority URL (`mailto:`/`tel:`/`sms:`), else `nil`.
    private static func bareScheme(of s: String) -> String? {
        guard let colon = s.firstIndex(of: ":") else { return nil }
        let candidate = s[s.startIndex..<colon].lowercased()
        return bareSchemes.contains(candidate) ? candidate : nil
    }

    /// Extract a filesystem path from a `file://…` URL (percent-decoded; host part,
    /// if any, dropped — best-effort), falling back to a manual strip.
    private static func filePath(fromFileURL s: String) -> String {
        if let url = URL(string: s), url.isFileURL { return url.path }
        // Manual: drop "file://", then an optional host up to the first "/".
        var rest = String(s.dropFirst("file://".count))
        if !rest.hasPrefix("/"), let slash = rest.firstIndex(of: "/") {
            rest = String(rest[slash...])
        }
        return filePath(fromRawPath: rest)
    }

    private static func filePath(fromRawPath s: String) -> String {
        s.removingPercentEncoding ?? s
    }

    /// Peel a trailing `:line` or `:line:column` (digits only) off a path.
    static func splitLineColumn(_ s: String) -> (path: String, line: Int?, column: Int?) {
        var path = s
        var nums: [Int] = []
        while nums.count < 2,
              let r = path.range(of: #":[0-9]+$"#, options: .regularExpression),
              let n = Int(path[path.index(after: r.lowerBound)..<r.upperBound]) {
            nums.insert(n, at: 0)
            path = String(path[..<r.lowerBound])
        }
        return (path, nums.first, nums.count >= 2 ? nums[1] : nil)
    }
}

// MARK: - File-path resolution

/// Resolves a (possibly relative) file path against a base working directory.
public enum FileLinkResolver {
    /// Expand `~`, then make `path` absolute against `cwd`. Returns `nil` for a
    /// relative/bare path when `cwd` is `nil` or empty (e.g. a remote session).
    /// Pure — `home` is supplied by the caller.
    public static func resolve(path: String, cwd: String?, home: String) -> String? {
        var p = path
        if p == "~" {
            p = home
        } else if p.hasPrefix("~/") {
            p = home + p.dropFirst(1)
        }
        if p.hasPrefix("/") {
            return (p as NSString).standardizingPath
        }
        guard let cwd, !cwd.isEmpty else { return nil }
        let joined = (cwd as NSString).appendingPathComponent(p)
        return (joined as NSString).standardizingPath
    }
}

// MARK: - Opener invocation

/// Builds the opener invocation for a resolved file target.
public enum OpenerBuilder {
    /// Editors recognized for the smart default (basename → builder).
    /// Terminal editors (vim/nvim/…) are deliberately absent → `open` fallback.
    public static func build(
        file path: String,
        line: Int?,
        column: Int?,
        template: String?,
        environment: [String: String]
    ) -> OpenerInvocation {
        if let template, !template.trimmingCharacters(in: .whitespaces).isEmpty {
            return .editorArgv(tokenize(template: template, file: path, line: line, column: column))
        }
        let editor = nonEmpty(environment["VISUAL"]) ?? nonEmpty(environment["EDITOR"])
        if let editor, let argv = inferEditorArgv(editor: editor, file: path, line: line, column: column) {
            return .editorArgv(argv)
        }
        return .systemOpenFile(path)
    }

    /// Split a template on whitespace and substitute `${file}`/`${line}`/
    /// `${column}` as whole tokens; a token referencing a missing line/column
    /// (with any adjacent `:`/`+`) collapses away, and empty tokens are dropped.
    static func tokenize(template: String, file: String, line: Int?, column: Int?) -> [String] {
        template.split(whereSeparator: { $0 == " " || $0 == "\t" }).compactMap { raw -> String? in
            var t = String(raw)
            t = t.replacingOccurrences(of: "${file}", with: file)
            if let line { t = t.replacingOccurrences(of: "${line}", with: String(line)) }
            if let column { t = t.replacingOccurrences(of: "${column}", with: String(column)) }
            // Drop any remaining (i.e. nil-valued) placeholders + an adjacent separator.
            for sep in [":", "+", ""] {
                t = t.replacingOccurrences(of: sep + "${line}", with: "")
                t = t.replacingOccurrences(of: sep + "${column}", with: "")
            }
            while t.hasSuffix(":") || t.hasSuffix("+") { t.removeLast() }
            return t.isEmpty ? nil : t
        }
    }

    /// Map a known editor (from `$VISUAL`/`$EDITOR`) to a line-aware argv, or
    /// `nil` for a terminal-only/unknown editor (→ caller falls back to `open`).
    static func inferEditorArgv(editor: String, file: String, line: Int?, column: Int?) -> [String]? {
        let bin = String(editor.split(whereSeparator: { $0 == " " || $0 == "\t" }).first ?? Substring(editor))
        guard !bin.isEmpty else { return nil }
        let name = (bin as NSString).lastPathComponent.lowercased()
        switch name {
        case "code", "code-insiders", "cursor", "windsurf", "codium", "vscodium":
            return [bin, "--goto", fileColonLoc(file, line, column)]
        case "subl", "sublime_text":
            return [bin, fileColonLoc(file, line, column)]
        case "mate":
            return line.map { [bin, "--line", String($0), file] } ?? [bin, file]
        case "idea", "idea.sh", "pycharm", "webstorm", "goland", "clion", "rubymine", "phpstorm", "rider":
            guard let line else { return [bin, file] }
            var argv = [bin, "--line", String(line)]
            if let column { argv += ["--column", String(column)] }
            argv.append(file)
            return argv
        case "emacs", "emacsclient":
            guard let line else { return [bin, file] }
            let pos = column.map { "+\(line):\($0)" } ?? "+\(line)"
            return [bin, pos, file]
        case "vim", "nvim", "vi", "nano", "micro", "helix", "hx", "kak", "emacs-nox":
            return nil  // terminal editors — can't usefully GUI-launch; fall back to `open`
        default:
            return nil  // unknown — fall back to `open` rather than guess
        }
    }

    /// `file` / `file:line` / `file:line:column` (collapsing missing parts).
    static func fileColonLoc(_ file: String, _ line: Int?, _ column: Int?) -> String {
        guard let line else { return file }
        guard let column else { return "\(file):\(line)" }
        return "\(file):\(line):\(column)"
    }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return s
    }
}

// MARK: - Router (the composed pure entry point)

/// Composes classification, the scheme guard, path resolution, and invocation
/// building into a single resolution. The app calls this, records the result for
/// the DEBUG dump, then performs the side effect.
public enum LinkRouter {
    /// Schemes the guard permits to reach the system URL opener.
    static let allowedURLSchemes: Set<String> = ["http", "https", "mailto"]

    public static func resolve(
        link: String,
        localCwd: String?,
        opener template: String?,
        environment: [String: String],
        home: String = NSHomeDirectory(),
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> LinkOpenResolution {
        switch LinkClassifier.classify(link) {
        case let .url(scheme, raw):
            guard allowedURLSchemes.contains(scheme) else { return .blocked(scheme: scheme) }
            return .open(target: .url(scheme: scheme, raw: raw), invocation: .openURL(raw))

        case let .file(path, line, column):
            guard let resolved = FileLinkResolver.resolve(path: path, cwd: localCwd, home: home) else {
                return .unresolved(reason: "relative path with no local working directory")
            }
            // Colon-in-filename: if `path` (sans the peeled line) doesn't exist but
            // the whole `path:line[:col]` does, treat the colon part as the name.
            if let line, !fileExists(resolved) {
                let whole = column.map { "\(path):\(line):\($0)" } ?? "\(path):\(line)"
                if let altResolved = FileLinkResolver.resolve(path: whole, cwd: localCwd, home: home),
                   fileExists(altResolved) {
                    let inv = OpenerBuilder.build(file: altResolved, line: nil, column: nil,
                                                  template: template, environment: environment)
                    return .open(target: .file(path: altResolved, line: nil, column: nil), invocation: inv)
                }
            }
            let inv = OpenerBuilder.build(file: resolved, line: line, column: column,
                                          template: template, environment: environment)
            return .open(target: .file(path: resolved, line: line, column: column), invocation: inv)
        }
    }
}
