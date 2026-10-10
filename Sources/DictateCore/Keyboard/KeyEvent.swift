import Foundation

package struct KeyEvent: Sendable {
    package enum Kind: Sendable {
        case modifiersChanged
        case keyDown
        case monitorDisabled
    }

    package let kind: Kind
    package let keyCode: Int64
    package let flags: UInt64
    package let timestamp: TimeInterval

    package init(kind: Kind, keyCode: Int64, flags: UInt64, timestamp: TimeInterval) {
        self.kind = kind
        self.keyCode = keyCode
        self.flags = flags
        self.timestamp = timestamp
    }
}
