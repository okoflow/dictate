import Foundation

package protocol MediaDecoder: Sendable {
    func samples(of url: URL) async throws -> [Float]
}
