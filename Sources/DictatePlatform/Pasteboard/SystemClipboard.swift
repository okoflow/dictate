import AppKit
import DictateCore

@MainActor
package final class SystemClipboard: Clipboard {
    package init() {}

    package func copy(_ text: String) {
        NSPasteboard.general.writePrivately(text)
    }
}
