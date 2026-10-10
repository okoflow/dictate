package enum PasteboardRestorePolicy {
    package enum Plan: Equatable, Sendable {
        case restore
        case skip(reason: String)
    }

    package static let maximumSnapshotBytes = 5 * 1024 * 1024
    package static let concealedType = "org.nspasteboard.ConcealedType"
    package static let transientType = "org.nspasteboard.TransientType"
    package static let dictateType = "dev.dictate.transcript"
    package static let markerTypes = [transientType, concealedType, dictateType]

    private static let restorableTypes: Set<String> = [
        "public.utf8-plain-text",
        "public.utf16-plain-text",
        "public.utf16-external-plain-text",
        "NSStringPboardType",
        "public.rtf",
        "public.html",
        "public.png",
        "public.jpeg",
        "public.tiff",
        "com.adobe.pdf",
        "public.file-url",
        "public.url",
        "public.url-name",
        concealedType,
        transientType,
        dictateType,
    ]

    package static func typesToSave(from types: [String]) -> [String] {
        let hasPNG = types.contains("public.png")

        return types.filter { restorableTypes.contains($0) && !(hasPNG && $0 == "public.tiff") }
    }

    package static func plan(currentTypes: [String], snapshotBytes: Int) -> Plan {
        let isDictateItem = currentTypes.contains(dictateType)
        let isPrivateItem = currentTypes.contains(concealedType) || currentTypes.contains(transientType)

        if isPrivateItem, !isDictateItem {
            return .skip(reason: "the clipboard holds a concealed or transient item")
        }

        if snapshotBytes > maximumSnapshotBytes {
            return .skip(reason: "the clipboard holds more than 5 MB")
        }

        return .restore
    }
}
