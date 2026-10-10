import DictateCore
import Foundation
import Observation
import os

@Observable
package final class DictationController {
    private enum Ending {
        case finish(releasedAt: TimeInterval)
        case discard(PushToTalk.DiscardReason)
    }

    private static let hudDelay = Duration.milliseconds(300)
    private static let watchdogInterval: TimeInterval = 0.25

    package private(set) var isRecording = false

    @ObservationIgnored private let recorder: any AudioRecorder
    @ObservationIgnored private let keyEventMonitor: any KeyEventMonitor
    @ObservationIgnored private let keyboardState: any KeyboardState
    @ObservationIgnored private let focusTracker: any FocusTracker
    @ObservationIgnored private let sounds: any FeedbackSoundPlayer
    @ObservationIgnored private let settings: SettingsModel
    @ObservationIgnored private let permissions: PermissionMonitor
    @ObservationIgnored private let speechModel: SpeechModelController
    @ObservationIgnored private let vocabulary: VocabularyModel
    @ObservationIgnored private let hud: HUDController
    @ObservationIgnored private let keyRecorder: KeyRecorder
    @ObservationIgnored private let queue: DictationQueue
    @ObservationIgnored private var pushToTalk = PushToTalk()
    @ObservationIgnored private var watchdog = ReleaseWatchdog()
    @ObservationIgnored private var recording: ActiveRecording?
    @ObservationIgnored private var lastRecordingID = RecordingID.none

    package var latestTranscript: String? {
        queue.latestTranscript
    }

    init(dependencies: AppDependencies, models: FeatureModels, queue: DictationQueue) {
        recorder = dependencies.recorder
        keyEventMonitor = dependencies.keyEventMonitor
        keyboardState = dependencies.keyboardState
        focusTracker = dependencies.focusTracker
        sounds = dependencies.sounds
        settings = models.settings
        permissions = models.permissions
        speechModel = models.speechModel
        vocabulary = models.vocabulary
        hud = models.hud
        keyRecorder = models.keyRecorder
        self.queue = queue
    }

    func start() {
        consumeKeyEvents()
        consumeRecorderEvents()
    }

    func waitUntilIdle() async {
        await queue.waitUntilIdle()
    }
}

extension DictationController {
    private func consumeKeyEvents() {
        Task { [weak self, events = keyEventMonitor.events] in
            for await event in events {
                self?.handle(event)
            }
        }
    }

    private func consumeRecorderEvents() {
        Task { [weak self, events = recorder.events] in
            for await event in events {
                self?.handle(event)
            }
        }
    }

    private func handle(_ keyEvent: KeyEvent) {
        guard !keyRecorder.isRecording else { return }

        let key = settings.settings.pushToTalkKey

        if key.isPressed(by: keyEvent) {
            watchdog.keyWasSeen()
        }

        guard let event = key.event(for: keyEvent) else { return }

        handle(event, at: keyEvent.timestamp)
    }

    private func handle(_ event: PushToTalk.Event, at time: TimeInterval) {
        pushToTalk.allowsHandsFree = settings.settings.handsFreeDoubleTap

        switch pushToTalk.handle(event, at: time) {
        case .startRecording:
            beginRecording()

        case .lockHandsFree:
            recording?.isHandsFree = true
            hud.lockHandsFree()

        case .finishRecording:
            endRecording(.finish(releasedAt: time))

        case let .discardRecording(reason):
            endRecording(.discard(reason))

        case nil:
            break
        }
    }

    private func handle(_ event: RecordingEvent) {
        switch event {
        case let .started(id, deviceName) where id == recording?.id:
            Logger.dictation.info("Recording from \(deviceName, privacy: .public)")

            if settings.settings.playsSounds {
                sounds.play(.recordingStarted)
            }

        case let .failed(id, reason) where id == recording?.id:
            failRecording(reason)

        case .started, .failed:
            break
        }
    }
}

extension DictationController {
    private func beginRecording() {
        lastRecordingID = lastRecordingID.next
        watchdog.reset()

        var started = ActiveRecording(id: lastRecordingID)
        started.watchdogTimer = .scheduledInCommonModes(every: Self.watchdogInterval, repeats: true) { [weak self] in
            self?.pollKey()
        }

        if let problem = reasonNotToRecord() {
            started.isRejected = true
            recording = started

            hud.show(HUDMessage(kind: .info, title: problem))

            return
        }

        started.hudTask = scheduleListeningHUD(for: started.id)
        recording = started
        isRecording = true

        let id = started.id
        let deviceID = settings.settings.microphoneID

        Task { await recorder.start(id, deviceID: deviceID) }
        Task { [weak self] in self?.captureTarget(for: id) }
    }

    private func reasonNotToRecord() -> String? {
        if !speechModel.state.isReady {
            return speechModel.state.notReadyMessage
        }

        if permissions.status(of: .microphone) == .denied {
            return "Dictate can't use the microphone. Allow it in Settings › General."
        }

        return nil
    }

    private func scheduleListeningHUD(for id: RecordingID) -> Task<Void, Never> {
        Task { [weak self] in
            try? await Task.sleep(for: Self.hudDelay)
            guard !Task.isCancelled else { return }

            self?.showListeningHUD(for: id)
        }
    }

    private func showListeningHUD(for id: RecordingID) {
        guard let recording, recording.id == id, !recording.hasFailed else { return }

        let mode = settings.settings.mode(for: recording.target?.bundleIdentifier)
        let recorder = recorder

        hud.showListening(badge: mode == .light ? nil : mode.title, isHandsFree: recording.isHandsFree) { recorder.inputLevel }
    }

    private func captureTarget(for id: RecordingID) {
        guard recording?.id == id else { return }

        recording?.target = focusTracker.currentFocus()
    }

    private func endRecording(_ ending: Ending) {
        guard let ended = recording else { return }

        recording = nil
        isRecording = false

        ended.hudTask?.cancel()
        ended.watchdogTimer?.invalidate()

        guard !ended.isRejected else { return }

        hud.hideListening()

        switch ending {
        case let .discard(reason):
            Logger.dictation.info("Discarded the recording: \(reason.rawValue, privacy: .public)")

            Task { _ = await recorder.stop(ended.id, releasedAt: nil) }

        case let .finish(releasedAt):
            if settings.settings.playsSounds {
                sounds.play(.recordingFinished)
            }

            Task { await finish(ended, releasedAt: releasedAt) }
        }
    }

    private func finish(_ ended: ActiveRecording, releasedAt: TimeInterval) async {
        let samples = await recorder.stop(ended.id, releasedAt: ended.hasFailed ? nil : releasedAt)
        guard !ended.hasFailed else { return }
        guard !samples.isEmpty else {
            let reason = await recorder.failureReason(for: ended.id) ?? "no audio was captured"

            hud.show(HUDMessage(kind: .warning, title: "Recording failed", detail: reason))

            return
        }

        submit(samples, target: ended.target ?? focusTracker.currentFocus())
    }

    private func submit(_ samples: [Float], target: FocusTarget) {
        let current = settings.settings
        let mode = current.mode(for: target.bundleIdentifier)

        if current.appModes.mode(for: target.bundleIdentifier) != nil {
            Logger.dictation.info("Using the app's own mode \(mode.rawValue, privacy: .public)")
        }

        queue.submit(DictationJob(
            samples: samples,
            language: current.languages.forcedLanguage,
            mode: mode,
            cloud: CloudRewrite(provider: current.cloudProvider, instructions: current.instructions.text(for: mode)),
            vocabulary: vocabulary.reloadFromDisk(),
            target: target,
            key: current.pushToTalkKey,
            pastes: current.pastesIntoFocusedField,
        ))
    }

    private func failRecording(_ reason: String) {
        guard var failed = recording, !failed.hasFailed else { return }

        failed.hasFailed = true
        recording = failed

        hud.hideListening()
        hud.show(HUDMessage(kind: .warning, title: "Recording failed", detail: reason))

        let id = failed.id

        Task { _ = await recorder.stop(id, releasedAt: nil) }
    }

    private func pollKey() {
        guard let recording else { return }

        let now = Uptime.now

        guard !recording.isHandsFree else {
            handle(.tick, at: now)

            return
        }

        let isHeld = keyboardState.isHeld(settings.settings.pushToTalkKey)

        switch watchdog.poll(isHeld: isHeld, at: now) {
        case .holding:
            handle(.tick, at: now)
        case let .released(since):
            Logger.dictation.notice("The key-up never arrived; ending the recording")

            handle(.keyUp, at: since)
        }
    }
}
