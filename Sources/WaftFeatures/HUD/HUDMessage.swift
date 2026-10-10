import Foundation

package struct HUDMessage: Equatable, Sendable {
    package enum Kind: Sendable {
        case pasted
        case copied
        case info
        case warning
    }

    package let kind: Kind
    package let title: String
    package let detail: String?

    var duration: Duration {
        let characters = title.count + (detail?.count ?? 0)
        let readingTime = min(10, 2 + Double(characters) / 15)
        let seconds = kind == .pasted ? min(readingTime, 4) : readingTime

        return .milliseconds(Int(seconds * 1000))
    }

    package init(kind: Kind, title: String, detail: String? = nil) {
        self.kind = kind
        self.title = title
        self.detail = detail
    }
}
