import ApplicationServices
import CoreGraphics
import DictateCore
import os

@MainActor
package final class ModifierKeyTap: KeyEventMonitor {
    package let events: AsyncStream<KeyEvent>

    private let continuation: AsyncStream<KeyEvent>.Continuation
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    package var isRunning: Bool {
        tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false
    }

    package init() {
        let stream = AsyncStream.makeStream(of: KeyEvent.self)
        events = stream.stream
        continuation = stream.continuation
    }

    package func start() -> Bool {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }

        if !isRunning {
            invalidateTap()
            installTap()
        }

        return isRunning
    }

    fileprivate func receive(_ event: KeyEvent) {
        continuation.yield(event)

        if event.kind == .monitorDisabled, let tap {
            CGEvent.tapEnable(tap: tap, enable: true)

            Logger.keyboard.notice("Re-enabled the key event tap after macOS switched it off")
        }
    }

    private func installTap() {
        guard AXIsProcessTrusted() || CGPreflightListenEventAccess(), let port = makeTap() else { return }

        let source = CFMachPortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)

        tap = port
        runLoopSource = source
    }

    private func invalidateTap() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        if let tap {
            CFMachPortInvalidate(tap)
        }

        tap = nil
        runLoopSource = nil
    }

    private func makeTap() -> CFMachPort? {
        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue) | CGEventMask(1 << CGEventType.keyDown.rawValue)

        return CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: modifierKeyTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque(),
        )
    }
}

private let modifierKeyTapCallback: CGEventTapCallBack = { _, type, event, context in
    guard let context, let kind = KeyEvent.Kind(type) else { return Unmanaged.passUnretained(event) }

    let timestamp = event.timestamp > 0 ? Double(event.timestamp) / 1_000_000_000 : Uptime.now
    let keyEvent = KeyEvent(
        kind: kind,
        keyCode: event.getIntegerValueField(.keyboardEventKeycode),
        flags: event.flags.rawValue,
        timestamp: timestamp,
    )
    let tap = Unmanaged<ModifierKeyTap>.fromOpaque(context).takeUnretainedValue()

    MainActor.assumeIsolated { tap.receive(keyEvent) }

    return Unmanaged.passUnretained(event)
}

extension KeyEvent.Kind {
    fileprivate init?(_ type: CGEventType) {
        switch type {
        case .flagsChanged: self = .modifiersChanged
        case .keyDown: self = .keyDown
        case .tapDisabledByTimeout, .tapDisabledByUserInput: self = .monitorDisabled
        default: return nil
        }
    }
}
