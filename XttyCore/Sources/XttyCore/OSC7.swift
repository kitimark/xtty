import Foundation

/// Decoder for OSC 7 (current working directory reports), view-free and
/// unit-testable.
///
/// The shell reports its cwd as a URL via OSC 7; SwiftTerm hands xtty the **raw,
/// undecoded** URL string. Two forms appear in the wild:
///   - `file://<host>/<percent-encoded-path>` (standard; path is percent-encoded)
///   - `kitty-shell-cwd://<host>/<raw-path>` (kitty/ghostty; path is NOT encoded)
/// A bare absolute path (no scheme) is also accepted leniently. A host that is
/// not the local machine is flagged remote so callers don't treat it as a local
/// filesystem path (e.g. a cwd reported over ssh).
public enum OSC7 {
    /// A decoded working directory: the filesystem path, the reporting host, and
    /// whether that host is remote (not the local machine).
    public struct WorkingDirectory: Equatable, Sendable {
        public let path: String
        public let host: String
        public let isRemote: Bool

        public init(path: String, host: String, isRemote: Bool) {
            self.path = path
            self.host = host
            self.isRemote = isRemote
        }
    }

    /// Decode an OSC 7 URL. `localHostNames` is the set of lowercased names that
    /// denote the local machine (e.g. `""`, `"localhost"`, the machine's
    /// hostname and its short form); a host outside that set is flagged remote.
    /// Returns `nil` when the input is empty or cannot be interpreted.
    public static func decode(_ raw: String, localHostNames: Set<String>) -> WorkingDirectory? {
        let url = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.isEmpty { return nil }

        // Split "<scheme>://<authority>/<path>" — authority is everything between
        // "//" and the first subsequent "/"; the path keeps that leading "/".
        let percentDecodePath: Bool
        let afterScheme: Substring
        if let r = url.range(of: "://") {
            let scheme = url[url.startIndex..<r.lowerBound].lowercased()
            switch scheme {
            case "file": percentDecodePath = true
            case "kitty-shell-cwd": percentDecodePath = false
            default: return nil  // unknown scheme — don't guess
            }
            afterScheme = url[r.upperBound...]
        } else if url.hasPrefix("/") {
            // Lenient: a bare absolute path with no scheme is a local cwd.
            return WorkingDirectory(path: url, host: "", isRemote: false)
        } else {
            return nil
        }

        // authority = up to the first "/", path = the rest (incl. the "/").
        let host: String
        let rawPath: String
        if let slash = afterScheme.firstIndex(of: "/") {
            host = String(afterScheme[afterScheme.startIndex..<slash])
            rawPath = String(afterScheme[slash...])
        } else {
            // No path component (e.g. "file://host"): treat the whole remainder as
            // the host with an empty path — nothing useful to start in.
            host = String(afterScheme)
            rawPath = ""
        }
        if rawPath.isEmpty { return nil }

        let path = percentDecodePath ? (rawPath.removingPercentEncoding ?? rawPath) : rawPath
        let isRemote = !localHostNames.contains(host.lowercased())
        return WorkingDirectory(path: path, host: host, isRemote: isRemote)
    }
}
