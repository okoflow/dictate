import DictateCore
import DictateFeatures
import DictatePlatform
import DictateSpeech
import Foundation

extension AppDependencies {
    static func live() -> AppDependencies {
        let focusTracker = AccessibilityFocusTracker()
        let keyboardState = SystemKeyboardState()
        let apiKeyStore = KeychainStore.anthropicAPIKey()
        let vocabularyFile = AppIdentity.supportDirectory.appending(path: "dictionary.json")
        let historyFile = AppIdentity.supportDirectory.appending(path: "history.json")

        return AppDependencies(
            recorder: AudioEngineRecorder(),
            audioInputs: CoreAudioInputs(),
            transcriber: WhisperTranscriber(),
            rewriter: AnthropicRewriter(apiKeyStore: apiKeyStore),
            keyEventMonitor: ModifierKeyTap(),
            keyboardState: keyboardState,
            modeShortcut: CarbonHotKey.modeCycle(),
            focusTracker: focusTracker,
            inserter: PasteboardInserter(focusTracker: focusTracker, keyboardState: keyboardState),
            clipboard: SystemClipboard(),
            permissions: SystemPermissions(),
            loginItem: MainAppLoginItem(),
            sounds: SystemSoundPlayer(),
            settingsStore: UserDefaultsStore<Settings>(key: "settings"),
            vocabularyStore: JSONFileStore<Vocabulary>(url: vocabularyFile),
            vocabularyFile: vocabularyFile,
            historyStore: JSONFileStore<DictationHistory>(url: historyFile, isPrivate: true),
            apiKeyStore: apiKeyStore,
        )
    }
}
