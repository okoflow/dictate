import Foundation

extension URL {
    init(literal: StaticString) {
        guard let url = URL(string: "\(literal)") else { preconditionFailure("Invalid URL literal: \(literal)") }

        self = url
    }
}
