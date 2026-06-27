import XCTest
@testable import XttyCore

final class HotKeyTests: XCTestCase {
    // MARK: HotKeyParser

    func testParsesSimpleChord() {
        let spec = HotKeyParser.parse("cmd+grave")
        XCTAssertEqual(spec?.virtualKeyCode, 0x32)
        XCTAssertEqual(spec?.modifiers, [.command])
        XCTAssertEqual(spec?.display, "⌘`")
    }

    func testParsesMultipleModifiers() {
        let spec = HotKeyParser.parse("ctrl+opt+t")
        XCTAssertEqual(spec?.modifiers, [.control, .option])
        XCTAssertEqual(spec?.virtualKeyCode, 0x11) // kVK_ANSI_T
        XCTAssertEqual(spec?.display, "⌃⌥T")
    }

    func testParsesNamedKeys() {
        XCTAssertEqual(HotKeyParser.parse("cmd+space")?.virtualKeyCode, 0x31)
        XCTAssertEqual(HotKeyParser.parse("cmd+up")?.virtualKeyCode, 0x7E)
        XCTAssertEqual(HotKeyParser.parse("cmd+f12")?.virtualKeyCode, 0x6F)
        XCTAssertEqual(HotKeyParser.parse("cmd+escape")?.virtualKeyCode, 0x35)
    }

    func testParsesPunctuationCharacter() {
        XCTAssertEqual(HotKeyParser.parse("cmd+`")?.virtualKeyCode, 0x32)
        XCTAssertEqual(HotKeyParser.parse("cmd+/")?.virtualKeyCode, 0x2C)
    }

    func testCaseAndWhitespaceInsensitive() {
        XCTAssertEqual(HotKeyParser.parse("  CMD + Grave ")?.virtualKeyCode, 0x32)
    }

    func testAliasEquivalence() {
        XCTAssertEqual(HotKeyParser.parse("command+option+t"), HotKeyParser.parse("cmd+alt+t"))
    }

    func testRejectsModifierOnly() {
        XCTAssertNil(HotKeyParser.parse("cmd+shift"))
    }

    func testRejectsKeyWithoutModifier() {
        XCTAssertNil(HotKeyParser.parse("grave"))
    }

    func testRejectsFnModifier() {
        XCTAssertNil(HotKeyParser.parse("fn+space"))
    }

    func testRejectsUnknownKey() {
        XCTAssertNil(HotKeyParser.parse("cmd+nope"))
    }

    func testRejectsMultipleKeys() {
        XCTAssertNil(HotKeyParser.parse("cmd+a+b"))
    }

    func testRejectsEmptyAndStrayPlus() {
        XCTAssertNil(HotKeyParser.parse(""))
        XCTAssertNil(HotKeyParser.parse("cmd++grave"))
        XCTAssertNil(HotKeyParser.parse("cmd+grave+"))
    }

    // MARK: HotKeyResolver

    func testResolverDisabledByDefault() {
        let s = HotKeyResolver.resolve(from: [:])
        XCTAssertFalse(s.enabled)
        XCTAssertNil(s.hotKey)
    }

    func testResolverDisabledWhenFlagOff() {
        let s = HotKeyResolver.resolve(from: ["quick-terminal": "false", "quick-terminal-hotkey": "cmd+grave"])
        XCTAssertEqual(s, .disabled)
    }

    func testResolverEnabledWithValidHotkey() {
        let s = HotKeyResolver.resolve(from: ["quick-terminal": "true", "quick-terminal-hotkey": "cmd+grave"])
        XCTAssertTrue(s.enabled)
        XCTAssertEqual(s.hotKey?.virtualKeyCode, 0x32)
    }

    func testResolverEnabledMissingHotkeyWarns() {
        var warned = false
        let s = HotKeyResolver.resolve(from: ["quick-terminal": "on"], warn: { _ in warned = true })
        XCTAssertTrue(s.enabled)
        XCTAssertNil(s.hotKey)
        XCTAssertTrue(warned)
    }

    func testResolverEnabledInvalidHotkeyWarns() {
        var warned = false
        let s = HotKeyResolver.resolve(
            from: ["quick-terminal": "true", "quick-terminal-hotkey": "fn"],
            warn: { _ in warned = true }
        )
        XCTAssertTrue(s.enabled)
        XCTAssertNil(s.hotKey)
        XCTAssertTrue(warned)
    }
}
