import XCTest
@testable import XttyCore

// Unit tests for the config layer. These run via `swift test` without launching
// the app or constructing a terminal view — parsing/resolution is pure, and disk
// loading is exercised against a temp directory injected as the home directory.
final class XttyConfigTests: XCTestCase {

    // MARK: Parsing

    func testParsesKeyValueWithCommentsAndWhitespace() {
        let text = """
        # a comment
        font-size = 14

          theme = dark
        # trailing comment
        """
        let pairs = XttyConfigLoader.parse(text)
        XCTAssertEqual(pairs["font-size"], "14")
        XCTAssertEqual(pairs["theme"], "dark")
        XCTAssertNil(pairs["# a comment"])
        XCTAssertEqual(pairs.count, 2)
    }

    func testParseLowercasesKeysAndKeepsLastDuplicate() {
        let pairs = XttyConfigLoader.parse("Font-Size = 12\nfont-size = 18")
        XCTAssertEqual(pairs["font-size"], "18")
    }

    func testParseKeepsEqualsInValue() {
        let pairs = XttyConfigLoader.parse("font-family = My = Font")
        XCTAssertEqual(pairs["font-family"], "My = Font")
    }

    // MARK: Resolution — recognized values

    func testRecognizedValuesAreApplied() {
        let config = XttyConfigLoader.resolve(from: [
            "font-family": "Menlo",
            "font-size": "15",
            "theme": "light",
            "scrollback": "2000",
            "option-as-meta": "false",
        ])
        XCTAssertEqual(config.fontFamily, "Menlo")
        XCTAssertEqual(config.fontSize, 15)
        XCTAssertEqual(config.themeName, "light")
        XCTAssertEqual(config.scrollback, 2000)
        XCTAssertEqual(config.optionAsMeta, false)
    }

    func testEmptyPairsYieldDefaults() {
        XCTAssertEqual(XttyConfigLoader.resolve(from: [:]), XttyConfig.default)
    }

    // MARK: Resolution — unknown keys & fallbacks

    func testUnknownKeyIsIgnoredAndRecognizedStillLoad() {
        let config = XttyConfigLoader.resolve(from: ["nonsense-key": "x", "font-size": "20"])
        XCTAssertEqual(config.fontSize, 20)
        XCTAssertEqual(config.themeName, XttyConfig.default.themeName)
    }

    func testInvalidFontSizeFallsBackAndWarns() {
        var warnings: [String] = []
        let config = XttyConfigLoader.resolve(from: ["font-size": "huge"]) { warnings.append($0) }
        XCTAssertEqual(config.fontSize, XttyConfig.default.fontSize)
        XCTAssertEqual(warnings.count, 1)
    }

    func testUnknownThemeFallsBackToDefaultAndWarns() {
        var warnings: [String] = []
        let config = XttyConfigLoader.resolve(from: ["theme": "neon"]) { warnings.append($0) }
        XCTAssertEqual(config.themeName, XttyConfig.default.themeName)
        XCTAssertEqual(config.theme, TerminalTheme.defaultTheme)
        XCTAssertEqual(warnings.count, 1)
    }

    func testInvalidScrollbackFallsBackAndWarns() {
        var warnings: [String] = []
        let config = XttyConfigLoader.resolve(from: ["scrollback": "-5"]) { warnings.append($0) }
        XCTAssertEqual(config.scrollback, XttyConfig.default.scrollback)
        XCTAssertEqual(warnings.count, 1)
    }

    func testScrollbackIsClampedToMax() {
        let config = XttyConfigLoader.resolve(from: ["scrollback": "99999999"])
        XCTAssertEqual(config.scrollback, XttyConfigLoader.scrollbackMax)
    }

    func testFontSizeIsClampedToRange() {
        XCTAssertEqual(XttyConfigLoader.resolve(from: ["font-size": "1"]).fontSize,
                       XttyConfigLoader.fontSizeRange.lowerBound)
        XCTAssertEqual(XttyConfigLoader.resolve(from: ["font-size": "999"]).fontSize,
                       XttyConfigLoader.fontSizeRange.upperBound)
    }

    func testOptionAsMetaParsesPermissiveBooleans() {
        for truthy in ["true", "YES", "1", "on"] {
            XCTAssertEqual(XttyConfigLoader.resolve(from: ["option-as-meta": truthy]).optionAsMeta, true)
        }
        for falsy in ["false", "no", "0", "OFF"] {
            XCTAssertEqual(XttyConfigLoader.resolve(from: ["option-as-meta": falsy]).optionAsMeta, false)
        }
    }

    func testLinkOpenerSetEmptyAbsent() {
        XCTAssertEqual(XttyConfigLoader.resolve(from: ["link-opener": "code --goto ${file}:${line}"]).linkOpener,
                       "code --goto ${file}:${line}")
        XCTAssertNil(XttyConfigLoader.resolve(from: ["link-opener": "   "]).linkOpener)
        XCTAssertNil(XttyConfigLoader.resolve(from: [:]).linkOpener)
    }

    func testLinkOpenerInheritedByProfileOverBase() {
        // A profile inherits the base link-opener and can override it.
        let base = XttyConfigLoader.resolve(from: ["link-opener": "code ${file}"])
        XCTAssertEqual(XttyConfigLoader.resolve(from: [:], base: base).linkOpener, "code ${file}")
        XCTAssertEqual(XttyConfigLoader.resolve(from: ["link-opener": "subl ${file}"], base: base).linkOpener,
                       "subl ${file}")
    }

    // MARK: Theme lookup

    func testThemeLookupIsCaseInsensitive() {
        XCTAssertEqual(TerminalTheme.named("DARK"), TerminalTheme.dark)
        XCTAssertEqual(TerminalTheme.named("Light"), TerminalTheme.light)
        XCTAssertNil(TerminalTheme.named("bogus"))
    }

    func testBuiltInThemesHave16AnsiColors() {
        for theme in TerminalTheme.builtIns {
            XCTAssertEqual(theme.ansi.count, 16, "theme \(theme.name) must have 16 ANSI colors")
        }
    }

    // MARK: Path discovery

    func testConfigPathUsesXDGWhenSet() {
        let path = XttyConfigLoader.configPath(
            environment: ["XDG_CONFIG_HOME": "/custom/cfg"],
            homeDirectory: "/Users/test"
        )
        XCTAssertEqual(path, "/custom/cfg/xtty/config")
    }

    func testConfigPathFallsBackToDotConfig() {
        let path = XttyConfigLoader.configPath(
            environment: [:],
            homeDirectory: "/Users/test"
        )
        XCTAssertEqual(path, "/Users/test/.config/xtty/config")
    }

    func testConfigPathIgnoresEmptyXDG() {
        let path = XttyConfigLoader.configPath(
            environment: ["XDG_CONFIG_HOME": ""],
            homeDirectory: "/Users/test"
        )
        XCTAssertEqual(path, "/Users/test/.config/xtty/config")
    }

    // MARK: Sectioned parsing (profiles)

    func testParseSectionsSplitsBaseAndNamedBlocks() {
        let text = """
        theme = dark
        [profile "work"]
        theme = light
        """
        let (base, profiles) = XttyConfigLoader.parseSections(text)
        XCTAssertEqual(base["theme"], "dark")
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.name, "work")
        XCTAssertEqual(profiles.first?.pairs["theme"], "light")
    }

    func testParseSectionsPreservesEnvKeyCase() {
        let (_, profiles) = XttyConfigLoader.parseSections("""
        [profile "work"]
        env-EDITOR = nvim
        """)
        XCTAssertEqual(profiles.first?.pairs["env-EDITOR"], "nvim")
        XCTAssertNil(profiles.first?.pairs["env-editor"], "env var name case must be preserved")
    }

    func testParseSectionsLowercasesNonEnvKeys() {
        let (base, _) = XttyConfigLoader.parseSections("Font-Size = 18")
        XCTAssertEqual(base["font-size"], "18")
    }

    func testParseSectionsSkipsMalformedHeaderButKeepsLoading() {
        var warnings: [String] = []
        let text = """
        theme = dark
        [profile work]
        theme = light
        [profile "ok"]
        font-size = 20
        """
        let (base, profiles) = XttyConfigLoader.parseSections(text) { warnings.append($0) }
        // Base keeps its keys; the malformed block's keys are dropped (not merged
        // into base or a phantom profile), and the later valid block still loads.
        XCTAssertEqual(base["theme"], "dark")
        XCTAssertEqual(profiles.map(\.name), ["ok"])
        XCTAssertEqual(profiles.first?.pairs["font-size"], "20")
        XCTAssertFalse(warnings.isEmpty, "a malformed header should warn")
    }

    func testParseSectionsEmptyNameHeaderIsSkipped() {
        var warnings: [String] = []
        let (_, profiles) = XttyConfigLoader.parseSections("""
        [profile ""]
        theme = light
        """) { warnings.append($0) }
        XCTAssertTrue(profiles.isEmpty)
        XCTAssertFalse(warnings.isEmpty)
    }

    func testParseSectionsMergesDuplicateNames() {
        var warnings: [String] = []
        let (_, profiles) = XttyConfigLoader.parseSections("""
        [profile "work"]
        theme = light
        font-size = 12
        [profile "work"]
        font-size = 16
        """) { warnings.append($0) }
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.pairs["theme"], "light")
        XCTAssertEqual(profiles.first?.pairs["font-size"], "16", "later duplicate key wins")
        XCTAssertFalse(warnings.isEmpty)
    }

    func testParseSectionsFlatFileHasNoProfiles() {
        let (base, profiles) = XttyConfigLoader.parseSections("theme = dark\nfont-size = 14")
        XCTAssertTrue(profiles.isEmpty)
        XCTAssertEqual(base["theme"], "dark")
        XCTAssertEqual(base["font-size"], "14")
    }

    // MARK: Profile set resolution

    func testResolveSetInheritsBaseAndOverrides() {
        let set = XttyConfigLoader.resolveSet(from: """
        font-family = JetBrains Mono
        theme = dark
        [profile "work"]
        theme = light
        """)
        let work = set.profiles["work"]
        XCTAssertEqual(work?.config.fontFamily, "JetBrains Mono", "inherited from base")
        XCTAssertEqual(work?.config.themeName, "light", "overridden")
        XCTAssertEqual(set.base.config.themeName, "dark")
    }

    func testResolveSetFlatEqualsOldResolve() {
        let text = "theme = light\nfont-size = 15\nscrollback = 2000\noption-as-meta = false"
        let set = XttyConfigLoader.resolveSet(from: text)
        XCTAssertEqual(set.base.config, XttyConfigLoader.resolve(from: XttyConfigLoader.parse(text)))
        XCTAssertTrue(set.profiles.isEmpty)
        XCTAssertNil(set.defaultProfileName)
        XCTAssertEqual(set.confirmClose, true)
    }

    func testResolveSetDefaultProfileSelection() {
        let set = XttyConfigLoader.resolveSet(from: """
        default-profile = work
        [profile "work"]
        theme = light
        """)
        XCTAssertEqual(set.defaultProfileName, "work")
        XCTAssertEqual(set.defaultProfile.name, "work")
    }

    func testResolveSetUnknownDefaultProfileFallsBackToBase() {
        var warnings: [String] = []
        let set = XttyConfigLoader.resolveSet(from: "default-profile = nope") { warnings.append($0) }
        XCTAssertNil(set.defaultProfileName)
        XCTAssertEqual(set.defaultProfile.name, nil, "falls back to base")
        XCTAssertFalse(warnings.isEmpty)
    }

    func testResolveSetParsesLaunchOverrides() {
        let set = XttyConfigLoader.resolveSet(from: """
        [profile "ssh"]
        command = ssh box
        cwd = ~/src/work
        env-EDITOR = nvim
        """)
        let launch = set.profiles["ssh"]?.launch
        XCTAssertEqual(launch?.command, "ssh box")
        XCTAssertEqual(launch?.cwd, "~/src/work")
        XCTAssertEqual(launch?.env["EDITOR"], "nvim")
    }

    func testResolveSetEnvPathIsIgnoredWithWarning() {
        var warnings: [String] = []
        let set = XttyConfigLoader.resolveSet(from: """
        [profile "x"]
        env-PATH = /tmp
        env-FOO = bar
        """) { warnings.append($0) }
        let launch = set.profiles["x"]?.launch
        XCTAssertNil(launch?.env["PATH"], "PATH is built by the login shell")
        XCTAssertEqual(launch?.env["FOO"], "bar")
        XCTAssertTrue(warnings.contains { $0.contains("PATH") })
    }

    func testResolveSetParsesConfirmClose() {
        XCTAssertEqual(XttyConfigLoader.resolveSet(from: "confirm-close = false").confirmClose, false)
        XCTAssertEqual(XttyConfigLoader.resolveSet(from: "confirm-close = true").confirmClose, true)
    }

    func testResolveSetParsesGitReviewLayout() {
        XCTAssertEqual(XttyConfigLoader.resolveSet(from: "git-review-layout = tree").gitReviewLayout, .tree)
        XCTAssertEqual(XttyConfigLoader.resolveSet(from: "git-review-layout = flat").gitReviewLayout, .flat)
        // Case-insensitive value (the key itself is already lowercased by parsing).
        XCTAssertEqual(XttyConfigLoader.resolveSet(from: "git-review-layout = TREE").gitReviewLayout, .tree)
    }

    func testResolveSetGitReviewLayoutDefaultsToFlat() {
        XCTAssertEqual(XttyConfigLoader.resolveSet(from: "").gitReviewLayout, .flat)
    }

    func testResolveSetInvalidGitReviewLayoutFallsBackAndWarns() {
        var warnings: [String] = []
        let set = XttyConfigLoader.resolveSet(from: "git-review-layout = grid") { warnings.append($0) }
        XCTAssertEqual(set.gitReviewLayout, .flat)
        XCTAssertTrue(warnings.contains { $0.contains("git-review-layout") })
    }

    func testResolveSetGitReviewLayoutInsideBlockIsIgnoredWithWarning() {
        var warnings: [String] = []
        let set = XttyConfigLoader.resolveSet(from: """
        git-review-layout = tree
        [profile "work"]
        git-review-layout = flat
        """) { warnings.append($0) }
        XCTAssertEqual(set.gitReviewLayout, .tree, "the base value wins; the profile copy is ignored")
        XCTAssertTrue(warnings.contains { $0.contains("git-review-layout") })
    }

    func testResolveSetDefaultProfileInsideBlockIsIgnoredWithWarning() {
        var warnings: [String] = []
        let set = XttyConfigLoader.resolveSet(from: """
        [profile "work"]
        default-profile = work
        """) { warnings.append($0) }
        XCTAssertNil(set.defaultProfileName)
        XCTAssertTrue(warnings.contains { $0.contains("default-profile") })
    }

    // MARK: Loading from disk

    func testLoadMissingFileReturnsDefaults() {
        let tmp = NSTemporaryDirectory() + "xtty-test-missing-\(getpid())"
        let config = XttyConfigLoader.load(environment: [:], homeDirectory: tmp)
        XCTAssertEqual(config, XttyConfig.default)
    }

    func testLoadReadsAndResolvesFile() throws {
        let home = NSTemporaryDirectory() + "xtty-test-home-\(getpid())-\(UUID().uuidString)"
        let dir = (home as NSString).appendingPathComponent(".config/xtty")
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let file = (dir as NSString).appendingPathComponent("config")
        try "theme = light\nscrollback = 1234\n".write(toFile: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: home) }

        let config = XttyConfigLoader.load(environment: [:], homeDirectory: home)
        XCTAssertEqual(config.themeName, "light")
        XCTAssertEqual(config.scrollback, 1234)
    }
}
