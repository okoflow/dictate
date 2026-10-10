import AppKit
import WaftCore

extension NSPasteboard {
    @discardableResult
    func writePrivately(_ item: NSPasteboardItem) -> Int {
        for type in PasteboardRestorePolicy.markerTypes {
            item.setData(Data(), forType: PasteboardType(type))
        }

        prepareForNewContents(with: .currentHostOnly)
        writeObjects([item])

        return changeCount
    }

    @discardableResult
    func writePrivately(_ text: String) -> Int {
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)

        return writePrivately(item)
    }
}
