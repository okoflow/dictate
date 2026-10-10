import AppKit
import DictateCore
import Foundation
import Observation

@Observable
package final class AppModel {
    package let settings: SettingsModel
    package let permissions: PermissionMonitor
    package let speechModel: SpeechModelController
    package let keyMonitor: KeyMonitorController
    package let dictation: DictationController
    package let modeSwitcher: ModeSwitcher
    package let history: HistoryModel
    package let stats: StatsModel
    package let vocabulary: VocabularyModel
    package let apiKeys: PerProvider<APIKeyModel>
    package let localModels: LocalModelsModel
    package let frontmostApp: FrontmostAppTracker
    package let hud: HUDController
    package let keyRecorder: KeyRecorder
    package let onboarding: OnboardingModel
    package let transcription: FileTranscriptionModel
    package let pro: ProModel

    @ObservationIgnored package let windows: WindowPresenter

    @ObservationIgnored private let clipboard: any Clipboard

    package var status: AppStatus {
        if dictation.isRecording {
            return .recording
        }

        if !permissions.allGranted || keyMonitor.status == .unavailable {
            return .needsPermission
        }

        switch speechModel.state.phase {
        case let .downloading(progress): return .downloading(progress)
        case .notInstalled, .loading: return .preparing
        case .failed: return .modelFailed
        case .ready: return .ready
        }
    }

    package var needsSetup: Bool {
        !settings.settings.hasCompletedSetup || !permissions.allGranted
    }

    package init(dependencies: AppDependencies) {
        let models = FeatureModels(dependencies: dependencies)

        settings = models.settings
        permissions = models.permissions
        speechModel = models.speechModel
        keyMonitor = KeyMonitorController(monitor: dependencies.keyEventMonitor)
        dictation = DictationController(
            dependencies: dependencies,
            models: models,
            queue: models.makeQueue(dependencies: dependencies),
        )
        modeSwitcher = ModeSwitcher(
            shortcut: dependencies.modeShortcut,
            settings: models.settings,
            hud: models.hud,
            pro: models.pro,
        )
        history = models.history
        stats = models.stats
        vocabulary = models.vocabulary
        apiKeys = PerProvider(
            claude: APIKeyModel(store: dependencies.apiKeyStores.claude),
            openAI: APIKeyModel(store: dependencies.apiKeyStores.openAI),
        )
        localModels = LocalModelsModel(browser: dependencies.localServers)
        frontmostApp = FrontmostAppTracker()
        hud = models.hud
        keyRecorder = models.keyRecorder
        onboarding = OnboardingModel()
        pro = models.pro
        transcription = FileTranscriptionModel(
            transcriber: dependencies.transcriber,
            decoder: dependencies.mediaDecoder,
            speechModel: models.speechModel,
            clipboard: dependencies.clipboard,
        )
        windows = WindowPresenter()
        clipboard = dependencies.clipboard

        windows.model = self
        connectModels()
    }

    package func start() {
        permissions.startMonitoring()
        speechModel.start()
        keyMonitor.start()
        dictation.start()
        modeSwitcher.start()
        history.keep(for: settings.settings.historyRetention, limit: settings.settings.historyLimit)
        hud.makePanel()

        if needsSetup {
            windows.showOnboarding()
        }
    }

    package func prepareToQuit() async {
        await dictation.waitUntilIdle()
    }

    package func copyLastTranscript() {
        if let text = dictation.latestTranscript {
            clipboard.copy(text)
        }
    }

    package func copy(_ entry: DictationHistory.Entry) {
        clipboard.copy(entry.text)
    }

    package func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func connectModels() {
        settings.onLanguagesChange = { [speechModel] languages in
            speechModel.reload(for: languages)
        }

        permissions.onChange = { [weak self] in
            self?.permissionsDidChange()
        }

        speechModel.onReady = { [weak self] in
            self?.speechModelDidBecomeReady()
        }

        onboarding.onFinish = { [weak self] in
            self?.finishOnboarding()
        }
    }

    private func permissionsDidChange() {
        if keyMonitor.status != .ready {
            keyMonitor.start()
        }

        if onboarding.step == .accessibility, permissions.status(of: .accessibility).isGranted {
            onboarding.advance()
        }
    }

    private func speechModelDidBecomeReady() {
        let key = settings.settings.pushToTalkKey.shortTitle

        hud.show(HUDMessage(kind: .info, title: String(localized: "Ready: hold \(key) and speak")))
    }

    private func finishOnboarding() {
        settings.settings.hasCompletedSetup = true

        windows.closeOnboarding()
    }
}
