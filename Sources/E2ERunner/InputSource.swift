import Carbon.HIToolbox
import Foundation

/// Switches the keyboard layout for the duration of a check, because "Option+a types å" is only
/// true for the US/ABC layout; on Russian or Korean layouts the same keys give something else.
enum InputSource {
    static let abc = "com.apple.keylayout.ABC"

    enum Failure: Error, CustomStringConvertible {
        case unavailable(String)
        case notSwitched(String)

        var description: String {
            switch self {
            case let .unavailable(id): "input source \(id) is not enabled in System Settings → Keyboard"
            case let .notSwitched(id): "the system did not switch to \(id)"
            }
        }
    }

    /// Runs `body` with `identifier` as the current layout and restores the previous one afterwards.
    @MainActor
    static func using<T>(_ identifier: String, _ body: () throws -> T) throws -> T {
        let previous = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let target = source(identifier) else { throw Failure.unavailable(identifier) }
        defer { TISSelectInputSource(previous) }
        if currentIdentifier() != identifier {
            TISSelectInputSource(target)
            guard waitUntil(timeout: 3, { currentIdentifier() == identifier }) else {
                throw Failure.notSwitched(identifier)
            }
        }
        return try body()
    }

    private static func source(_ identifier: String) -> TISInputSource? {
        let filter = ["TISPropertyInputSourceID": identifier] as CFDictionary
        let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource]
        return list?.first
    }

    private static func currentIdentifier() -> String? {
        let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let raw = TISGetInputSourceProperty(current, "TISPropertyInputSourceID" as CFString) else { return nil }
        return Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
    }
}
