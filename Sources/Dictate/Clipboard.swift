import AppKit

/// Puts dictated text on the general pasteboard.
enum Clipboard {
    /// nspasteboard.org conventions: clipboard managers skip items marked like this, so dictated
    /// text (which may be private) does not end up in their history. Pasting is not affected.
    private static let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    private static let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        // `currentHostOnly` keeps the item off Universal Clipboard, so a transcript never reaches a phone
        // or another Mac. (It replaces `clearContents()`, and `declareTypes` would drop the option again.)
        pasteboard.prepareForNewContents(with: .currentHostOnly)
        pasteboard.setString(text, forType: .string)
        pasteboard.setData(Data(), forType: transient)
        pasteboard.setData(Data(), forType: concealed)
    }
}
