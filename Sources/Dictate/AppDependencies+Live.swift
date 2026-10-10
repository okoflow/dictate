import DictateCore
import DictateFeatures
import DictatePlatform
import DictateSpeech
import Foundation

extension AppDependencies {
    static func live() -> AppDependencies {
        let focusTracker = AccessibilityFocusTracker()
        let keyboardState = SystemKeyboardState()
        let apiKeyStores = PerProvider<any ValueStore<String>>(
            claude: KeychainStore.apiKey(for: .claude),
            openAI: KeychainStore.apiKey(for: .openAI),
        )
        let vocabularyFile = AppIdentity.supportDirectory.appending(path: "dictionary.json")
        let historyFile = AppIdentity.supportDirectory.appending(path: "history.json")

        return AppDependencies(
            recorder: AudioEngineRecorder(),
            audioInputs: CoreAudioInputs(),
            transcriber: WhisperTranscriber(),
            rewriters: PerProvider<any TextRewriter>(
                claude: AnthropicRewriter(apiKeyStore: apiKeyStores.claude),
                openAI: OpenAIRewriter(apiKeyStore: apiKeyStores.openAI),
            ),
            keyEventMonitor: KeyEventTap(),
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
            apiKeyStores: apiKeyStores,
        )
    }
}
