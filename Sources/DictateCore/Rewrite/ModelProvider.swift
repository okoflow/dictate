import Foundation

package enum ModelProvider: Hashable, Sendable {
    case apple
    case localServer
    case cloud(CloudProvider)

    package var title: String {
        switch self {
        case .apple: "Apple Intelligence"
        case .localServer: String(localized: "Local server")
        case let .cloud(provider): provider.title
        }
    }

    package var isCloud: Bool {
        if case .cloud = self {
            true
        } else {
            false
        }
    }

    package var deadline: Duration {
        isCloud ? .seconds(3) : .seconds(15)
    }

    private var storedName: String {
        switch self {
        case .apple: "apple"
        case .localServer: "local"
        case let .cloud(provider): provider.rawValue
        }
    }

    private init(storedName: String) {
        switch storedName {
        case "apple": self = .apple
        case "local": self = .localServer
        default: self = .cloud(CloudProvider(rawValue: storedName) ?? .claude)
        }
    }
}

extension ModelProvider: Codable {
    package init(from decoder: any Decoder) throws {
        try self.init(storedName: decoder.singleValueContainer().decode(String.self))
    }

    package func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storedName)
    }
}
