import AppKit

// AppKit entry point — deliberately NOT the SwiftUI `App` lifecycle: SwiftUI's
// private app delegate owns `NSApp.mainMenu` under that lifecycle and rewrites
// the installed menu's items in place on a per-launch race (the menu clobber;
// `research/03-analysis/swiftui-mainmenu-clobber-forensics.md`). Under
// `NSApplicationMain` that machinery is never instantiated.
//
// `NSApplication.delegate` is weak: this top-level `let` is the strong
// retention that `@NSApplicationDelegateAdaptor` used to provide — do not
// inline it into the assignment.
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
