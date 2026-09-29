import AppKit
import DictateCore

/// What was on the clipboard before a paste, so it can be put back afterwards.
struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]
    let plan: InsertionRules.RestorePlan

    /// Reads every item with every restorable type, giving up on the data once it passes the size cap
    /// (the plan then says to skip the restore).
    static func take(from pasteboard: NSPasteboard = .general) -> PasteboardSnapshot {
        var allTypes: [String] = []
        var bytes = 0
        var items: [[NSPasteboard.PasteboardType: Data]] = []
        for item in pasteboard.pasteboardItems ?? [] {
            var contents: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                allTypes.append(type.rawValue)
                guard InsertionRules.isRestorable(type: type.rawValue),
                      bytes <= InsertionRules.maximumSnapshotBytes,
                      let data = item.data(forType: type)
                else { continue }
                bytes += data.count
                contents[type] = data
            }
            items.append(contents)
        }
        return PasteboardSnapshot(items: items, plan: InsertionRules.restorePlan(currentTypes: allTypes, snapshotBytes: bytes))
    }

    func restore(to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        let restored = items.filter { !$0.isEmpty }.map { contents -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in contents {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(restored)
    }
}
