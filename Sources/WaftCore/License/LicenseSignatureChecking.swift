import Foundation

package protocol LicenseSignatureChecking: Sendable {
    func isValid(_ signature: Data, for payload: Data) -> Bool
}
