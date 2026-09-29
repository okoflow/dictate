import AppKit
import DictateCore

/// What was on the clipboard before a paste, so it can be put back afterwards. Only the content types on
/// the allowlist (`InsertionRules.typesToSave`) are kept, and the snapshot is abandoned as soon as it
/// passes the size cap.
struct PasteboardSnapshot: Sendable {
    private let items: [[NSPasteboard.PasteboardType: Data]]
    let plan: InsertionRules.RestorePlan
    /// The clipboard held a text Dictate itself put there; it goes back host-only, like it was.
    private let isOurs: Bool

    /// Reads the clipboard. The data of a big item can take a while to arrive, so this runs off the main
    /// thread (see `Inserter`), before the paste starts.
    static func take(from pasteboard: NSPasteboard = .general) -> PasteboardSnapshot {
        var allTypes: [String] = []
        var bytes = 0
        var items: [[NSPasteboard.PasteboardType: Data]] = []
        for item in pasteboard.pasteboardItems ?? [] {
            let types = item.types.map(\.rawValue)
            allTypes += types
            var contents: [NSPasteboard.PasteboardType: Data] = [:]
            for type in InsertionRules.typesToSave(from: types) where bytes <= InsertionRules.maximumSnapshotBytes {
                guard let data = item.data(forType: NSPasteboard.PasteboardType(type)) else { continue }
                bytes += data.count
                contents[NSPasteboard.PasteboardType(type)] = data
            }
            items.append(contents)
        }
        return PasteboardSnapshot(
            items: items,
            plan: InsertionRules.restorePlan(currentTypes: allTypes, snapshotBytes: bytes),
            isOurs: allTypes.contains(InsertionRules.ownType)
        )
    }

    func restore(to pasteboard: NSPasteboard = .general) {
        if isOurs {
            pasteboard.prepareForNewContents(with: .currentHostOnly)
        } else {
            pasteboard.clearContents()
        }
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
