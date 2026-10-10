import DictateCore
import Foundation
import Security

package struct KeychainStore: ValueStore {
    private enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
    }

    private let service: String
    private let account: String

    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    package init(service: String, account: String) {
        self.service = service
        self.account = account
    }

    package static func license() -> KeychainStore {
        KeychainStore(service: AppIdentity.bundleIdentifier, account: "license-key")
    }

    package static func apiKey(for provider: CloudProvider) -> KeychainStore {
        switch provider {
        case .claude: KeychainStore(service: AppIdentity.bundleIdentifier, account: "anthropic-api-key")
        case .openAI: KeychainStore(service: AppIdentity.bundleIdentifier, account: "openai-api-key")
        }
    }

    package func load() -> String? {
        var search = query
        search[kSecReturnData as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(search as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }

        let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

        return value?.isEmpty == false ? value : nil
    }

    package func exists() -> Bool {
        var search = query
        search[kSecReturnAttributes as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne

        return SecItemCopyMatching(search as CFDictionary, nil) == errSecSuccess
    }

    package func save(_ value: String) throws {
        delete()

        var item = query
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    package func delete() {
        SecItemDelete(query as CFDictionary)
    }
}
