import AppKit

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
/// - **Font size** → custom selectors `target`ed at the app delegate, which owns
///   the terminal controller.
enum XttyMainMenu {
    /// Build the full main menu. `fontActionTarget` receives the font-size
    /// selectors (`increaseFontSize:` / `decreaseFontSize:` / `resetFontSize:`).
    static func build(fontActionTarget: AnyObject?) -> NSMenu {
        let main = NSMenu()

        main.addItem(appMenuItem())
        main.addItem(editMenuItem())
        main.addItem(viewMenuItem(target: fontActionTarget))
        main.addItem(windowMenuItem())

        return main
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

    private static func editMenuItem() -> NSMenuItem {
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
        menu.addItem(findMenuItem())

        item.submenu = menu
        return item
    }

    /// The Find submenu. Each item uses `performFindPanelAction:` with a tag that
    /// SwiftTerm reads to choose show / next / previous.
    private static func findMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Find", action: nil, keyEquivalent: "")
        let menu = NSMenu(title: "Find")
        let action = #selector(NSTextView.performFindPanelAction(_:))

        let find = NSMenuItem(title: "Find…", action: action, keyEquivalent: "f")
        find.tag = Int(NSFindPanelAction.showFindPanel.rawValue)

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

    private static func viewMenuItem(target: AnyObject?) -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "View")

        let bigger = NSMenuItem(title: "Increase Font Size",
                                action: #selector(AppDelegate.increaseFontSize(_:)),
                                keyEquivalent: "+")
        let smaller = NSMenuItem(title: "Decrease Font Size",
                                 action: #selector(AppDelegate.decreaseFontSize(_:)),
                                 keyEquivalent: "-")
        let reset = NSMenuItem(title: "Actual Size",
                               action: #selector(AppDelegate.resetFontSize(_:)),
                               keyEquivalent: "0")

        for entry in [bigger, smaller, reset] {
            entry.target = target
            menu.addItem(entry)
        }

        item.submenu = menu
        return item
    }

    // MARK: Window menu

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
