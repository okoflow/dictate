import DictateCore
import Foundation

package struct JSONFileStore<Value: Codable & Sendable>: ValueStore {
    package let url: URL

    private let isPrivate: Bool

    package init(url: URL, isPrivate: Bool = false) {
        self.url = url
        self.isPrivate = isPrivate
    }

    package func load() throws -> Value? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        return try JSONDecoder().decode(Value.self, from: Data(contentsOf: url))
    }

    package func save(_ value: Value) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]

        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(value).write(to: url, options: .atomic)

        if isPrivate {
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
    }

    package func exists() -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    package func delete() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        try FileManager.default.removeItem(at: url)
    }
}
