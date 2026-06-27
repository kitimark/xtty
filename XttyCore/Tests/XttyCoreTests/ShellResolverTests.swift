import XCTest
@testable import XttyCore

// Unit tests for ShellResolver. These run via `swift test` without launching the
// app or constructing a terminal view — the resolution logic is pure and uses
// injected probes for the filesystem / account database.
final class ShellResolverTests: XCTestCase {

    // MARK: resolveShellPath fallback chain

    func testHonorsExecutableShellEnv() {
        let path = ShellResolver.resolveShellPath(
            shellEnv: "/opt/homebrew/bin/fish",
            isExecutable: { $0 == "/opt/homebrew/bin/fish" },
            accountShell: { "/bin/zsh" }
        )
        XCTAssertEqual(path, "/opt/homebrew/bin/fish")
    }

    func testFallsBackToAccountShellWhenShellEnvUnset() {
        let path = ShellResolver.resolveShellPath(
            shellEnv: nil,
            isExecutable: { $0 == "/bin/zsh" },
            accountShell: { "/bin/zsh" }
        )
        XCTAssertEqual(path, "/bin/zsh")
    }

    func testFallsBackToAccountShellWhenShellEnvNotExecutable() {
        let path = ShellResolver.resolveShellPath(
            shellEnv: "/no/such/shell",
            isExecutable: { $0 == "/usr/local/bin/bash" },
            accountShell: { "/usr/local/bin/bash" }
        )
        XCTAssertEqual(path, "/usr/local/bin/bash")
    }

    func testFallsBackToDefaultWhenNothingExecutable() {
        let path = ShellResolver.resolveShellPath(
            shellEnv: "/no/such/shell",
            isExecutable: { _ in false },
            accountShell: { "/also/missing" }
        )
        XCTAssertEqual(path, ShellResolver.defaultShell)
        XCTAssertEqual(path, "/bin/zsh")
    }

    func testIgnoresEmptyShellEnv() {
        let path = ShellResolver.resolveShellPath(
            shellEnv: "",
            isExecutable: { _ in true },
            accountShell: { "/bin/zsh" }
        )
        XCTAssertEqual(path, "/bin/zsh")
    }

    // MARK: launchConfig — login argv[0]

    func testLoginArgvHasLeadingDash() {
        let config = ShellResolver.launchConfig(forShell: "/bin/zsh", environment: [:])
        XCTAssertEqual(config.execName, "-zsh")
        XCTAssertEqual(config.executable, "/bin/zsh")
        XCTAssertEqual(config.args, [])
    }

    func testLoginArgvUsesBasename() {
        let config = ShellResolver.launchConfig(forShell: "/opt/homebrew/bin/fish", environment: [:])
        XCTAssertEqual(config.execName, "-fish")
    }

    // MARK: launchConfig — seed environment

    func testSeedEnvironmentContents() {
        let config = ShellResolver.launchConfig(forShell: "/bin/zsh", environment: ["LANG": "en_GB.UTF-8"])
        XCTAssertEqual(config.environment["TERM"], "xterm-256color")
        XCTAssertEqual(config.environment["COLORTERM"], "truecolor")
        XCTAssertEqual(config.environment["LANG"], "en_GB.UTF-8")
    }

    func testSeedEnvironmentDefaultsLangWhenMissing() {
        let config = ShellResolver.launchConfig(forShell: "/bin/zsh", environment: [:])
        XCTAssertEqual(config.environment["LANG"], "en_US.UTF-8")
    }

    func testSeedEnvironmentDoesNotReconstructPath() {
        let config = ShellResolver.launchConfig(
            forShell: "/bin/zsh",
            environment: ["PATH": "/should/not/be/copied"]
        )
        XCTAssertNil(config.environment["PATH"],
                     "PATH must be built by the login shell, not seeded by xtty")
    }

    func testSeedEnvironmentMirrorsIdentityVars() {
        let config = ShellResolver.launchConfig(
            forShell: "/bin/zsh",
            environment: ["HOME": "/Users/test", "USER": "test", "LOGNAME": "test"]
        )
        // HOME must carry over so the login shell finds ~/.zprofile / ~/.zshrc.
        XCTAssertEqual(config.environment["HOME"], "/Users/test")
        XCTAssertEqual(config.environment["USER"], "test")
        XCTAssertEqual(config.environment["LOGNAME"], "test")
    }

    func testSeedEnvironmentOmitsAbsentIdentityVars() {
        let config = ShellResolver.launchConfig(forShell: "/bin/zsh", environment: [:])
        XCTAssertNil(config.environment["HOME"])
        XCTAssertNil(config.environment["USER"])
    }
}
