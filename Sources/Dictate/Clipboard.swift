import AppKit

/// Puts dictated text on the general pasteboard.
enum Clipboard {
    /// nspasteboard.org conventions: clipboard managers skip items marked like this, so dictated
    /// text (which may be private) does not end up in their history. Pasting is not affected.
    private static let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    private static let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([.string, transient, concealed], owner: nil)
        pasteboard.setString(text, forType: .string)
        pasteboard.setData(Data(), forType: transient)
        pasteboard.setData(Data(), forType: concealed)
    }
}
