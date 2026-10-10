import AppKit
import DictateCore

struct PasteboardSnapshot: Sendable {
    let plan: PasteboardRestorePolicy.Plan

    private let items: [[String: Data]]
    private let isDictateItem: Bool

    static func take(from pasteboard: NSPasteboard = .general) -> PasteboardSnapshot {
        var allTypes: [String] = []
        var byteCount = 0
        var items: [[String: Data]] = []

        for item in pasteboard.pasteboardItems ?? [] {
            let types = item.types.map(\.rawValue)
            allTypes += types

            var contents: [String: Data] = [:]

            for type in PasteboardRestorePolicy.typesToSave(from: types)
                where byteCount <= PasteboardRestorePolicy.maximumSnapshotBytes {
                guard let data = item.data(forType: NSPasteboard.PasteboardType(type)) else { continue }

                byteCount += data.count
                contents[type] = data
            }

            items.append(contents)
        }

        return PasteboardSnapshot(
            plan: PasteboardRestorePolicy.plan(currentTypes: allTypes, snapshotBytes: byteCount),
            items: items,
            isDictateItem: allTypes.contains(PasteboardRestorePolicy.dictateType),
        )
    }

    func restore(to pasteboard: NSPasteboard = .general) {
        if isDictateItem {
            pasteboard.prepareForNewContents(with: .currentHostOnly)
        } else {
            pasteboard.clearContents()
        }

        let restored = items.filter { !$0.isEmpty }.map { contents in
            let item = NSPasteboardItem()

            for (type, data) in contents {
                item.setData(data, forType: NSPasteboard.PasteboardType(type))
            }

            return item
        }

        pasteboard.writeObjects(restored)
    }
}
