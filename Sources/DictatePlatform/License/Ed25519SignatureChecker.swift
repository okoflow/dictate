import CryptoKit
import DictateCore
import Foundation

package struct Ed25519SignatureChecker: LicenseSignatureChecking {
    package static let licensePublicKey = "ILFVseTSw4B4Cfx699xDRoFH00t0pg9rX+h6qCEIEO0="

    private let publicKey: Curve25519.Signing.PublicKey?

    package init(publicKey: String = Self.licensePublicKey) {
        self.publicKey = Data(base64Encoded: publicKey).flatMap { try? Curve25519.Signing.PublicKey(rawRepresentation: $0) }
    }

    package func isValid(_ signature: Data, for payload: Data) -> Bool {
        publicKey?.isValidSignature(signature, for: payload) ?? false
    }
}
