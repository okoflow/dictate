import Foundation

package struct License: Codable, Equatable, Sendable {
    package let id: String
    package let email: String
    package let name: String?
    package let issued: String
}
