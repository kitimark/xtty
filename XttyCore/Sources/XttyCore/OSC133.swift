import Foundation

/// A parsed OSC 133 semantic-prompt action.
public enum SemanticAction: Equatable, Sendable {
    /// `A` (fresh-line + prompt start) or `P` (prompt start).
    case promptStart
    /// `B` (prompt end / command input start).
    case promptEnd
    /// `C` (command input end / output start).
    case commandStart
    /// `D` (command end), with the reported exit code (`nil` for a bare `D`).
    case commandEnd(exitCode: Int32?)
}

/// One parsed OSC 133 mark: the action plus the fields a block model needs.
public struct SemanticMark: Equatable, Sendable {
    public let action: SemanticAction
    /// The command text decoded from a `cmdline`/`cmdline_url` option (on `C`).
    public let command: String?
    /// Whether this is a continuation/secondary prompt (`k=s`) — callers must not
    /// start a new command for it.
    public let isContinuation: Bool

    public init(action: SemanticAction, command: String? = nil, isContinuation: Bool = false) {
        self.action = action
        self.command = command
        self.isContinuation = isContinuation
    }
}

/// Parser for OSC 133 (FinalTerm semantic prompts), view-free and unit-testable.
///
/// SwiftTerm has no built-in OSC 133 handling; xtty registers a handler via
/// `registerOscHandler(code: 133)`. SwiftTerm splits the OSC string on the first
/// `;`, so the handler receives the payload AFTER `133;` — e.g. for
/// `OSC 133 ; D ; 1 ; aid=foo` the payload is `D;1;aid=foo`.
///
/// Grammar: `<ACTION>[;<token>;<token>…]` where each token is `key=value` (split
/// on the FIRST `=`), except for `D` whose first token is a bare positional
/// integer exit code. Unknown action bytes are ignored (return `nil`).
public enum OSC133 {
    /// Parse an OSC 133 payload (the bytes after `133;`). Returns `nil` for an
    /// empty payload or an unrecognized action.
    public static func parse(_ payload: String) -> SemanticMark? {
        guard let actionChar = payload.first else { return nil }

        // Options follow only when the char after the action is ';'.
        let afterAction = payload.dropFirst()
        var tokens: [String] = []
        if afterAction.first == ";" {
            tokens = afterAction.dropFirst()
                .split(separator: ";", omittingEmptySubsequences: false)
                .map(String.init)
        }

        func optionValue(_ key: String) -> String? {
            for token in tokens {
                guard let eq = token.firstIndex(of: "=") else { continue }
                if token[token.startIndex..<eq] == Substring(key) {
                    return String(token[token.index(after: eq)...])
                }
            }
            return nil
        }

        let isContinuation = optionValue("k") == "s"

        // Command text: prefer percent-encoded cmdline_url, else shell-quoted
        // cmdline; both fall back to the raw value if decoding fails.
        var command: String? = nil
        if let raw = optionValue("cmdline_url") {
            command = raw.removingPercentEncoding ?? raw
        } else if let raw = optionValue("cmdline") {
            command = dequoteShell(raw)
        }

        switch actionChar {
        case "A", "P":
            return SemanticMark(action: .promptStart, command: command, isContinuation: isContinuation)
        case "B":
            return SemanticMark(action: .promptEnd, command: command, isContinuation: isContinuation)
        case "C":
            return SemanticMark(action: .commandStart, command: command, isContinuation: isContinuation)
        case "D":
            // The exit code is the FIRST token when it's a bare integer (not k=v).
            var exitCode: Int32? = nil
            if let first = tokens.first, !first.isEmpty, !first.contains("="),
               let code = Int32(first) {
                exitCode = code
            }
            return SemanticMark(action: .commandEnd(exitCode: exitCode), command: command, isContinuation: isContinuation)
        default:
            return nil  // unknown action byte (e.g. kitty `k`) — ignore
        }
    }

    /// Minimal `%q`-style unquoting for a `cmdline` value: drop a backslash that
    /// escapes the following character (so `\ ` → space, `\\` → `\`). Best-effort
    /// — sufficient for the common case; ambiguous escapes degrade to the raw text.
    static func dequoteShell(_ s: String) -> String {
        var out = ""
        var escaped = false
        for ch in s {
            if escaped {
                out.append(ch)
                escaped = false
            } else if ch == "\\" {
                escaped = true
            } else {
                out.append(ch)
            }
        }
        if escaped { out.append("\\") }
        return out
    }
}
