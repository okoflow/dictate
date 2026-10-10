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
        let localServer = LocalServerRewriter()
        let appleIntelligence = AppleIntelligence()
        let vocabularyFile = AppIdentity.supportDirectory.appending(path: "dictionary.json")
        let historyFile = AppIdentity.supportDirectory.appending(path: "history.json")
        let statsFile = AppIdentity.supportDirectory.appending(path: "stats.json")

        return AppDependencies(
            recorder: AudioEngineRecorder(),
            audioInputs: CoreAudioInputs(),
            transcriber: WhisperTranscriber(),
            rewriters: rewriters(keys: apiKeyStores, localServer: localServer, apple: appleIntelligence),
            localServers: localServer,
            onDeviceModel: appleIntelligence,
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
            statsStore: JSONFileStore<DictationStats>(url: statsFile),
            apiKeyStores: apiKeyStores,
        )
    }

    private static func rewriters(
        keys: PerProvider<any ValueStore<String>>,
        localServer: LocalServerRewriter,
        apple: AppleIntelligence,
    ) -> Rewriters {
        Rewriters(
            cloud: PerProvider(
                claude: AnthropicRewriter(apiKeyStore: keys.claude),
                openAI: OpenAIRewriter(apiKeyStore: keys.openAI),
            ),
            localServer: localServer,
            apple: apple,
        )
    }
}
