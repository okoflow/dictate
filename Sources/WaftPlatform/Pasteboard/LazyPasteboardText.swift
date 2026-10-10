import AppKit
import os

final class LazyPasteboardText: NSObject, NSPasteboardItemDataProvider, @unchecked Sendable {
    private struct State {
        var isArmed = false
        var wasRead = false
    }

    private let text: String
    private let state = OSAllocatedUnfairLock(initialState: State())

    var wasReadAfterArming: Bool {
        state.withLock { $0.wasRead }
    }

    init(_ text: String) {
        self.text = text
    }

    func arm() {
        state.withLock { $0.isArmed = true }
    }

    func pasteboard(_: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
        item.setString(text, forType: type)
        state.withLock { $0.wasRead = $0.wasRead || $0.isArmed }
    }

    func pasteboardFinishedWithDataProvider(_: NSPasteboard) {}
}
