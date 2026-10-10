import Foundation
import WaftCore
import WaftPlatform
import WaftSpeech

enum LegacyDataMigration {
    private static let bundleIdentifier = "dev.dictate.app"
    private static let supportDirectory = URL.applicationSupportDirectory.appending(path: "Dictate", directoryHint: .isDirectory)
    private static let cacheDirectory = URL.cachesDirectory.appending(path: bundleIdentifier, directoryHint: .isDirectory)
    private static let completionMarker = ".dictate-complete"
    private static let keychainAccounts = ["anthropic-api-key", "openai-api-key", "license-key"]

    static func run() {
        let defaults = UserDefaults.standard
        guard defaults.persistentDomain(forName: AppIdentity.bundleIdentifier) == nil,
              let legacy = defaults.persistentDomain(forName: bundleIdentifier) else { return }

        for (key, value) in legacy {
            defaults.set(value, forKey: key)
        }
        defaults.removePersistentDomain(forName: bundleIdentifier)

        moveSupportDirectory()
        copyKeychainItems()
        try? FileManager.default.removeItem(at: cacheDirectory)
    }

    private static func moveSupportDirectory() {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: supportDirectory.path),
              !fileManager.fileExists(atPath: AppIdentity.supportDirectory.path),
              (try? fileManager.moveItem(at: supportDirectory, to: AppIdentity.supportDirectory)) != nil else { return }

        let models = SpeechModelFiles.defaultBaseDirectory.appending(path: "models/\(SpeechModelFiles.repository)")
        let folders = (try? fileManager.contentsOfDirectory(at: models, includingPropertiesForKeys: nil)) ?? []

        for folder in folders {
            try? fileManager.moveItem(
                at: folder.appending(path: completionMarker),
                to: folder.appending(path: SpeechModelFiles.completionMarker),
            )
        }
    }

    private static func copyKeychainItems() {
        for account in keychainAccounts {
            let legacy = KeychainStore(service: bundleIdentifier, account: account)
            let current = KeychainStore(service: AppIdentity.bundleIdentifier, account: account)
            guard legacy.exists(), !current.exists(), let value = legacy.load() else { continue }

            try? current.save(value)
        }
    }
}
