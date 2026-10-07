import AppKit
import Foundation
import Observation
import Security

/// The Anthropic API key in the login Keychain (a generic password, service `dev.dictate.app`, account
/// `anthropic-api-key`). It is read when a cloud mode needs it and never written anywhere else: not to
/// `UserDefaults`, logs or arguments.
enum APIKeyStore {
    static let service = "dev.dictate.app"
    static let account = "anthropic-api-key"

    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func read() -> String? {
        var item: CFTypeRef?
        var search = query
        search[kSecReturnData as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne
        guard SecItemCopyMatching(search as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty
        else { return nil }
        return key
    }

    @discardableResult
    static func save(_ key: String) -> Bool {
        delete()
        var item = query
        item[kSecValueData as String] = Data(key.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }
}

/// Whether a key is set, for the menu, and the dialog that sets it.
@MainActor
@Observable
final class APIKeySettings {
    private(set) var isSet = APIKeyStore.read() != nil

    /// Asks for the key in a small dialog with a secure field. An empty answer changes nothing.
    func promptForKey() {
        let alert = NSAlert()
        alert.messageText = "Anthropic API key"
        alert.informativeText = "Used by Clean, Formal and Translate: the recognised text (never audio) is sent to Claude Haiku. "
            + "Stored in your Keychain."
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.placeholderString = "sk-ant-…"
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        // A menu bar app is never active on its own; the dialog must come to the front.
        NSApplication.shared.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        APIKeyStore.save(key)
        refresh()
    }

    func remove() {
        APIKeyStore.delete()
        refresh()
    }

    func refresh() {
        isSet = APIKeyStore.read() != nil
    }
}
