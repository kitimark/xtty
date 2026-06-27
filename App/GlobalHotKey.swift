import AppKit
import Carbon.HIToolbox
import XttyCore

/// A registered system-wide hotkey, backed by Carbon's `RegisterEventHotKey`.
///
/// Carbon is the only global-hotkey API that needs **no** Accessibility/TCC
/// permission and can fire while xtty is unfocused (design D1). The surface is
/// tiny, so we hand-roll it rather than add a dependency (D2). The C event
/// handler is `@convention(c)` and carries no Swift context, so it bounces
/// through an `Unmanaged` `self` pointer passed as `userData` (D2).
///
/// Failable: a non-`noErr` registration (e.g. a system-reserved combo like
/// ⌘Space) returns `nil` so the caller disables the feature fail-soft (D11).
/// The hotkey is unregistered on `deinit`, so the owner just drops the instance.
///
/// Ownership: a `GlobalHotKey` is owned solely by `AppDelegate` (created and
/// released on the main thread), so the Carbon refs are only touched on the main
/// thread — in `init` and the nonisolated `deinit`, with no concurrent access.
/// That single-owner, main-thread contract is what makes the `nonisolated(unsafe)`
/// refs below safe.
@MainActor
final class GlobalHotKey {
    // Owned by `AppDelegate` on the main thread (see the ownership note above);
    // written only in `init`, read only in the nonisolated `deinit`, never raced.
    // The opaque Carbon pointers aren't Sendable, so the isolation is vouched for.
    nonisolated(unsafe) private var hotKeyRef: EventHotKeyRef?
    nonisolated(unsafe) private var handlerRef: EventHandlerRef?
    private let callback: () -> Void
    private static var nextID: UInt32 = 1

    init?(spec: HotKeySpec, callback: @escaping () -> Void) {
        self.callback = callback

        // Install one application-level handler for hot-key-pressed events; the
        // handler dispatches back into this instance via the userData pointer.
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        var installedHandler: EventHandlerRef?
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        // Explicitly typed as `EventHandlerUPP` (a `@convention(c)` function
        // pointer), so an accidental capture is a compile error rather than a
        // silent conversion failure. It carries no Swift context; the instance is
        // recovered from `userData`.
        let handler: EventHandlerUPP = { _, _, userData in
            guard let userData else { return noErr }
            let instance = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            // Carbon delivers hot-key events on the main run loop, where
            // `assumeIsolated` is valid. Guard defensively: an unexpected off-main
            // delivery logs and is dropped rather than tripping a fatal assertion.
            if Thread.isMainThread {
                MainActor.assumeIsolated { instance.callback() }
            } else {
                NSLog("[xtty] global hotkey fired off the main thread; ignoring")
            }
            return noErr
        }
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(), handler, 1, &eventType, selfPtr, &installedHandler
        )
        guard installStatus == noErr else { return nil }
        self.handlerRef = installedHandler

        let hotKeyID = EventHotKeyID(signature: GlobalHotKey.signature, id: GlobalHotKey.nextID)
        GlobalHotKey.nextID &+= 1
        var registered: EventHotKeyRef?
        let registerStatus = RegisterEventHotKey(
            spec.virtualKeyCode,
            GlobalHotKey.carbonModifiers(spec.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &registered
        )
        guard registerStatus == noErr, let registered else {
            if let installedHandler { RemoveEventHandler(installedHandler) }
            self.handlerRef = nil
            return nil  // e.g. a reserved combo — caller disables fail-soft
        }
        self.hotKeyRef = registered
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }

    /// Four-char-code `'xtty'` signature for our hotkey IDs.
    private static let signature: OSType =
        Array("xtty".utf8).reduce(OSType(0)) { ($0 << 8) + OSType($1) }

    /// Map the toolkit-independent `ModifierSet` to Carbon's modifier mask — the
    /// app-layer adapter for the "one model, two adapters" split `ModifierSet`
    /// documents (the menu adapter is `KeybindAdapter`).
    private static func carbonModifiers(_ modifiers: ModifierSet) -> UInt32 {
        var mask: UInt32 = 0
        if modifiers.contains(.command) { mask |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { mask |= UInt32(shiftKey) }
        if modifiers.contains(.option) { mask |= UInt32(optionKey) }
        if modifiers.contains(.control) { mask |= UInt32(controlKey) }
        return mask
    }
}
