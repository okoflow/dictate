import ApplicationServices
import CoreGraphics
import DictateCore
import Foundation

/// Watches the keyboard for the push-to-talk hotkey through a session event tap.
///
/// The tap is **listen-only**: it can observe but never swallow events, so Option+letter keeps
/// reaching the focused app untouched and only the Input Monitoring permission is needed.
@MainActor
final class HotkeyMonitor {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let onSignal: (KeyboardSignal, Double) -> Void
    private let onTapReenabled: () -> Void

    /// `onSignal` receives each relevant keyboard signal with its time in seconds (the event's own
    /// timestamp, not the moment it was handled, so main-thread delays do not skew hold times).
    init(onSignal: @escaping (KeyboardSignal, Double) -> Void, onTapReenabled: @escaping () -> Void) {
        self.onSignal = onSignal
        self.onTapReenabled = onTapReenabled
    }

    /// Installs the tap. Returns `false` when macOS refuses, which means Input Monitoring is missing.
    func start() -> Bool {
        guard tap == nil else { return true }
        // `tapCreate` on a denied process fails silently (or, on some systems, prompts again and
        // again), so ask whether we may before trying.
        guard CGPreflightListenEventAccess() else { return false }
        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue) | CGEventMask(1 << CGEventType.keyDown.rawValue)
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: hotkeyTapCallback,
            userInfo: context
        ) else { return false }
        let runLoopSource = CFMachPortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        tap = port
        source = runLoopSource
        return true
    }

    fileprivate func receive(_ event: RawKeyEvent, at time: Double) {
        let signal = Hotkey.classify(event)
        guard signal != .ignored else { return }
        onSignal(signal, time)
        if signal == .tapDisabled, let tap {
            // macOS switches a tap off when it is too slow or when secure input starts; without
            // this the hotkey would silently stop working until the next launch.
            CGEvent.tapEnable(tap: tap, enable: true)
            onTapReenabled()
        }
    }
}

/// Seconds on the clock that `CGEvent.timestamp` uses (nanoseconds since boot).
func uptimeSeconds() -> Double {
    Double(DispatchTime.now().uptimeNanoseconds) / 1e9
}

/// The tap callback is a C function: it cannot capture anything, so the monitor arrives as an
/// opaque pointer. It runs on the main run loop, where the tap's source was added.
private let hotkeyTapCallback: CGEventTapCallBack = { _, type, event, context in
    guard let context else { return Unmanaged.passUnretained(event) }
    let raw = RawKeyEvent(
        kind: RawKeyEvent.Kind(type),
        keyCode: event.getIntegerValueField(.keyboardEventKeycode),
        flags: event.flags.rawValue
    )
    // Tap-disabled notifications carry no timestamp.
    let time = event.timestamp > 0 ? Double(event.timestamp) / 1e9 : uptimeSeconds()
    let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(context).takeUnretainedValue()
    MainActor.assumeIsolated { monitor.receive(raw, at: time) }
    return Unmanaged.passUnretained(event)
}

private extension RawKeyEvent.Kind {
    init(_ type: CGEventType) {
        switch type {
        case .flagsChanged: self = .flagsChanged
        case .keyDown: self = .keyDown
        case .tapDisabledByTimeout: self = .tapDisabledByTimeout
        case .tapDisabledByUserInput: self = .tapDisabledByUserInput
        default: self = .other
        }
    }
}
