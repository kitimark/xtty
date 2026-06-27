import AppKit
import XttyCore

/// Builds xtty's main menu in **AppKit**, not SwiftUI `.commands`.
///
/// **Why AppKit (the P2 spike finding):** SwiftTerm's find is driven by
/// `performFindPanelAction(_:)`, which requires the *sender* to be an
/// `NSMenuItem` whose `.tag` selects the action (show / next / previous). A
/// SwiftUI `Button` closure cannot supply that sender. A real `NSMenuItem` with
/// `target: nil` travels the **key window's responder chain** straight to the
/// terminal view (the first responder), which is plain AppKit — no SwiftUI↔AppKit
/// hop of the kind that caused P1's black-render. So the whole menu is built in
/// AppKit and installed as `NSApp.mainMenu`.
///
/// Routing:
/// - **Find / Copy / Paste / Select All** → `target: nil` → first responder
///   (the SwiftTerm view implements and validates these).
/// - **Font size** → `target: nil` → first responder, handled by the focused
///   pane's `XttyTerminalView` (design D3: pane-scoped commands ride the
///   responder chain, so "the active pane" is just the first responder).
enum XttyMainMenu {
    /// Build the full main menu, with key equivalents from the resolved
    /// `Keybindings` (the `terminal-keybindings` capability).
    @MainActor
    static func build(keybindings: Keybindings) -> NSMenu {
        let main = NSMenu()

        main.addItem(appMenuItem())
        main.addItem(editMenuItem(keybindings: keybindings))
        main.addItem(viewMenuItem(keybindings: keybindings))
        main.addItem(terminalMenuItem(keybindings: keybindings))
        main.addItem(windowMenuItem())

        return main
    }

    // MARK: Terminal menu (splits + pane focus; tabs/windows added in layer 3)

    @MainActor
    private static func terminalMenuItem(keybindings: Keybindings) -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Terminal")

        func make(_ title: String, _ action: Selector, _ binding: KeyAction) -> NSMenuItem {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
            KeybindAdapter.apply(keybindings.chord(for: binding), to: entry)
            entry.target = nil  // responder chain → focused pane's XttyTerminalView
            return entry
        }

        menu.addItem(make("New Tab", #selector(XttyTerminalView.newTerminalTab(_:)), .newTab))
        menu.addItem(make("New Window", #selector(XttyTerminalView.newTerminalWindow(_:)), .newWindow))
        menu.addItem(.separator())
        menu.addItem(make("Split Right", #selector(XttyTerminalView.splitPaneRight(_:)), .splitRight))
        menu.addItem(make("Split Down", #selector(XttyTerminalView.splitPaneDown(_:)), .splitDown))
        menu.addItem(.separator())
        menu.addItem(make("Close Pane", #selector(XttyTerminalView.closePane(_:)), .close))
        menu.addItem(.separator())
        menu.addItem(make("Select Pane on Left", #selector(XttyTerminalView.focusPaneLeft(_:)), .focusLeft))
        menu.addItem(make("Select Pane on Right", #selector(XttyTerminalView.focusPaneRight(_:)), .focusRight))
        menu.addItem(make("Select Pane Above", #selector(XttyTerminalView.focusPaneUp(_:)), .focusUp))
        menu.addItem(make("Select Pane Below", #selector(XttyTerminalView.focusPaneDown(_:)), .focusDown))

        item.submenu = menu
        return item
    }

    // MARK: App menu

    private static func appMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu()
        let appName = ProcessInfo.processInfo.processName

        menu.addItem(withTitle: "About \(appName)",
                     action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                     keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Hide \(appName)",
                     action: #selector(NSApplication.hide(_:)),
                     keyEquivalent: "h")
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit \(appName)",
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        menu.addItem(quit)

        item.submenu = menu
        return item
    }

    // MARK: Edit menu (Copy / Paste / Select All + Find)

    @MainActor
    private static func editMenuItem(keybindings: Keybindings) -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Edit")

        menu.addItem(withTitle: "Copy",
                     action: #selector(NSText.copy(_:)),
                     keyEquivalent: "c")
        menu.addItem(withTitle: "Paste",
                     action: #selector(NSText.paste(_:)),
                     keyEquivalent: "v")
        menu.addItem(withTitle: "Select All",
                     action: #selector(NSText.selectAll(_:)),
                     keyEquivalent: "a")
        menu.addItem(.separator())
        menu.addItem(findMenuItem(keybindings: keybindings))

        item.submenu = menu
        return item
    }

    /// The Find submenu. Each item uses `performFindPanelAction:` with a tag that
    /// SwiftTerm reads to choose show / next / previous. The "Find…" item's key
    /// equivalent comes from the `find` keybinding; next/previous stay conventional.
    @MainActor
    private static func findMenuItem(keybindings: Keybindings) -> NSMenuItem {
        let item = NSMenuItem(title: "Find", action: nil, keyEquivalent: "")
        let menu = NSMenu(title: "Find")
        let action = #selector(NSTextView.performFindPanelAction(_:))

        let find = NSMenuItem(title: "Find…", action: action, keyEquivalent: "")
        find.tag = Int(NSFindPanelAction.showFindPanel.rawValue)
        KeybindAdapter.apply(keybindings.chord(for: .find), to: find)

        let next = NSMenuItem(title: "Find Next", action: action, keyEquivalent: "g")
        next.tag = Int(NSFindPanelAction.next.rawValue)

        let prev = NSMenuItem(title: "Find Previous", action: action, keyEquivalent: "g")
        prev.keyEquivalentModifierMask = [.command, .shift]
        prev.tag = Int(NSFindPanelAction.previous.rawValue)

        for entry in [find, next, prev] {
            entry.target = nil // responder chain → the terminal view
            menu.addItem(entry)
        }

        item.submenu = menu
        return item
    }

    // MARK: View menu (font size)

    @MainActor
    private static func viewMenuItem(keybindings: Keybindings) -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "View")

        let bigger = NSMenuItem(title: "Increase Font Size",
                                action: #selector(XttyTerminalView.increaseFontSize(_:)),
                                keyEquivalent: "")
        let smaller = NSMenuItem(title: "Decrease Font Size",
                                 action: #selector(XttyTerminalView.decreaseFontSize(_:)),
                                 keyEquivalent: "")
        let reset = NSMenuItem(title: "Actual Size",
                               action: #selector(XttyTerminalView.resetFontSize(_:)),
                               keyEquivalent: "")

        KeybindAdapter.apply(keybindings.chord(for: .fontIncrease), to: bigger)
        KeybindAdapter.apply(keybindings.chord(for: .fontDecrease), to: smaller)
        KeybindAdapter.apply(keybindings.chord(for: .fontReset), to: reset)

        // target: nil → responder chain → the focused pane's XttyTerminalView.
        for entry in [bigger, smaller, reset] {
            entry.target = nil
            menu.addItem(entry)
        }

        item.submenu = menu
        return item
    }

    // MARK: Window menu

    @MainActor
    private static func windowMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Window")
        menu.addItem(withTitle: "Minimize",
                     action: #selector(NSWindow.performMiniaturize(_:)),
                     keyEquivalent: "m")
        menu.addItem(withTitle: "Zoom",
                     action: #selector(NSWindow.performZoom(_:)),
                     keyEquivalent: "")
        item.submenu = menu
        NSApp.windowsMenu = menu
        return item
    }
}
