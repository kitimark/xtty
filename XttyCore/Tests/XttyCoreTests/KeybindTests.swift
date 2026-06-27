import XCTest
@testable import XttyCore

// Unit tests for the view-free keybinding model: chord parsing, presets, and
// preset-plus-override resolution. Pure — no app, no AppKit.

final class KeybindTests: XCTestCase {

    // MARK: Parser

    func testParsesModifiersAndKey() {
        XCTAssertEqual(KeybindParser.parse("cmd+d"),
                       KeyChord(key: .character("d"), modifiers: [.command]))
        XCTAssertEqual(KeybindParser.parse("cmd+shift+d"),
                       KeyChord(key: .character("d"), modifiers: [.command, .shift]))
        XCTAssertEqual(KeybindParser.parse("cmd+opt+left"),
                       KeyChord(key: .arrowLeft, modifiers: [.command, .option]))
    }

    func testParserIsCaseAndAliasInsensitive() {
        XCTAssertEqual(KeybindParser.parse("Command+Alt+RIGHT"),
                       KeyChord(key: .arrowRight, modifiers: [.command, .option]))
        XCTAssertEqual(KeybindParser.parse("control+ shift +t"),
                       KeyChord(key: .character("t"), modifiers: [.control, .shift]))
    }

    func testParsesNamedSymbolKeys() {
        XCTAssertEqual(KeybindParser.parse("cmd+plus"), KeyChord(key: .character("+"), modifiers: [.command]))
        XCTAssertEqual(KeybindParser.parse("cmd+minus"), KeyChord(key: .character("-"), modifiers: [.command]))
        XCTAssertEqual(KeybindParser.parse("cmd+["), KeyChord(key: .character("["), modifiers: [.command]))
    }

    func testRejectsInvalidChords() {
        XCTAssertNil(KeybindParser.parse("d"), "bare key (no modifier) is rejected")
        XCTAssertNil(KeybindParser.parse("cmd"), "modifiers only is rejected")
        XCTAssertNil(KeybindParser.parse(""), "empty is rejected")
        XCTAssertNil(KeybindParser.parse("cmd++"), "trailing/empty token is rejected")
        XCTAssertNil(KeybindParser.parse("cmd+d+t"), "two non-modifier keys is rejected")
        XCTAssertNil(KeybindParser.parse("cmd+nope"), "unknown multi-char token is rejected")
    }

    // MARK: Presets

    func testPresetsShareCommonAndDifferOnFocus() {
        let iterm = Keybindings.preset(.iterm)
        let ghostty = Keybindings.preset(.ghostty)

        // Common bindings agree.
        XCTAssertEqual(iterm[.splitRight], KeyChord(key: .character("d"), modifiers: [.command]))
        XCTAssertEqual(ghostty[.splitRight], KeyChord(key: .character("d"), modifiers: [.command]))
        XCTAssertEqual(iterm[.newTab], ghostty[.newTab])

        // Focus differs: iterm uses Cmd+Opt+arrows, ghostty uses Cmd+[ / Cmd+].
        XCTAssertEqual(iterm[.focusLeft], KeyChord(key: .arrowLeft, modifiers: [.command, .option]))
        XCTAssertEqual(ghostty[.focusLeft], KeyChord(key: .character("["), modifiers: [.command]))
        XCTAssertEqual(ghostty[.focusRight], KeyChord(key: .character("]"), modifiers: [.command]))
    }

    func testEveryActionIsBoundInEachPreset() {
        for style in KeybindStyle.allCases {
            let map = Keybindings.preset(style)
            for action in KeyAction.allCases {
                XCTAssertNotNil(map[action], "\(style) preset missing \(action)")
            }
        }
    }

    // MARK: Resolution from config

    func testStyleSelectionAndDefault() {
        XCTAssertEqual(KeybindResolver.resolve(from: [:]).chord(for: .focusLeft),
                       KeyChord(key: .arrowLeft, modifiers: [.command, .option]),
                       "default style is iterm")
        XCTAssertEqual(KeybindResolver.resolve(from: ["keybind-style": "ghostty"]).chord(for: .focusLeft),
                       KeyChord(key: .character("["), modifiers: [.command]))
    }

    func testUnknownStyleFallsBackAndWarns() {
        var warnings: [String] = []
        let kb = KeybindResolver.resolve(from: ["keybind-style": "vim"], warn: { warnings.append($0) })
        XCTAssertEqual(kb.chord(for: .splitRight), KeyChord(key: .character("d"), modifiers: [.command]))
        XCTAssertFalse(warnings.isEmpty)
    }

    func testOverrideReplacesOnlyThatAction() {
        let kb = KeybindResolver.resolve(from: [
            "keybind-style": "iterm",
            "keybind-split-down": "cmd+ctrl+j",
        ])
        XCTAssertEqual(kb.chord(for: .splitDown), KeyChord(key: .character("j"), modifiers: [.command, .control]))
        // Others keep the preset.
        XCTAssertEqual(kb.chord(for: .splitRight), KeyChord(key: .character("d"), modifiers: [.command]))
        XCTAssertEqual(kb.chord(for: .focusLeft), KeyChord(key: .arrowLeft, modifiers: [.command, .option]))
    }

    func testInvalidOverrideKeepsPresetAndWarns() {
        var warnings: [String] = []
        let kb = KeybindResolver.resolve(from: ["keybind-close": "nope"], warn: { warnings.append($0) })
        XCTAssertEqual(kb.chord(for: .close), KeyChord(key: .character("w"), modifiers: [.command]))
        XCTAssertFalse(warnings.isEmpty)
    }
}
