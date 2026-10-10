import DictateCore
import Foundation

package struct AppDependencies {
    package let recorder: any AudioRecorder
    package let audioInputs: any AudioInputProvider
    package let transcriber: any Transcriber
    package let mediaDecoder: any MediaDecoder
    package let rewriters: Rewriters
    package let localServers: any LocalServerBrowsing
    package let onDeviceModel: any OnDeviceModel
    package let keyEventMonitor: any KeyEventMonitor
    package let keyboardState: any KeyboardState
    package let modeShortcut: any GlobalShortcut
    package let focusTracker: any FocusTracker
    package let inserter: any TextInserter
    package let clipboard: any Clipboard
    package let permissions: any PermissionProvider
    package let loginItem: any LoginItem
    package let sounds: any FeedbackSoundPlayer
    package let settingsStore: any ValueStore<Settings>
    package let vocabularyStore: any ValueStore<Vocabulary>
    package let vocabularyFile: URL
    package let historyStore: any ValueStore<DictationHistory>
    package let statsStore: any ValueStore<DictationStats>
    package let apiKeyStores: PerProvider<any ValueStore<String>>
    package let licenseStore: any ValueStore<String>
    package let trialStore: any ValueStore<Date>
    package let licenseChecker: any LicenseSignatureChecking

    package init(
        recorder: any AudioRecorder,
        audioInputs: any AudioInputProvider,
        transcriber: any Transcriber,
        mediaDecoder: any MediaDecoder,
        rewriters: Rewriters,
        localServers: any LocalServerBrowsing,
        onDeviceModel: any OnDeviceModel,
        keyEventMonitor: any KeyEventMonitor,
        keyboardState: any KeyboardState,
        modeShortcut: any GlobalShortcut,
        focusTracker: any FocusTracker,
        inserter: any TextInserter,
        clipboard: any Clipboard,
        permissions: any PermissionProvider,
        loginItem: any LoginItem,
        sounds: any FeedbackSoundPlayer,
        settingsStore: any ValueStore<Settings>,
        vocabularyStore: any ValueStore<Vocabulary>,
        vocabularyFile: URL,
        historyStore: any ValueStore<DictationHistory>,
        statsStore: any ValueStore<DictationStats>,
        apiKeyStores: PerProvider<any ValueStore<String>>,
        licenseStore: any ValueStore<String>,
        trialStore: any ValueStore<Date>,
        licenseChecker: any LicenseSignatureChecking,
    ) {
        self.recorder = recorder
        self.audioInputs = audioInputs
        self.transcriber = transcriber
        self.mediaDecoder = mediaDecoder
        self.rewriters = rewriters
        self.localServers = localServers
        self.onDeviceModel = onDeviceModel
        self.keyEventMonitor = keyEventMonitor
        self.keyboardState = keyboardState
        self.modeShortcut = modeShortcut
        self.focusTracker = focusTracker
        self.inserter = inserter
        self.clipboard = clipboard
        self.permissions = permissions
        self.loginItem = loginItem
        self.sounds = sounds
        self.settingsStore = settingsStore
        self.vocabularyStore = vocabularyStore
        self.vocabularyFile = vocabularyFile
        self.historyStore = historyStore
        self.statsStore = statsStore
        self.apiKeyStores = apiKeyStores
        self.licenseStore = licenseStore
        self.trialStore = trialStore
        self.licenseChecker = licenseChecker
    }
}
