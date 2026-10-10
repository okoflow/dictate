import Foundation

package struct LicenseKey: Sendable {
    private static let prefix = "DCT1"

    package let license: License
    package let payload: Data
    package let signature: Data

    package init?(_ text: String) {
        let compact = String(text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) })
        let parts = compact.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == Self.prefix,
              let payload = Self.decoded(parts[1]), let signature = Self.decoded(parts[2]),
              let license = try? JSONDecoder().decode(License.self, from: payload)
        else { return nil }

        self.license = license
        self.payload = payload
        self.signature = signature
    }

    private static func decoded(_ part: Substring) -> Data? {
        var base64 = part.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)

        return Data(base64Encoded: base64)
    }
}
