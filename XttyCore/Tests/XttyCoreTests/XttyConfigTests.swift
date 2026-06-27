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
