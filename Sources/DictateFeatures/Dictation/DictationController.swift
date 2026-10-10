import DictateCore
import Foundation
import Observation
import os

@Observable
package final class DictationController {
    enum Ending {
        case finish(releasedAt: TimeInterval)
        case discard(PushToTalk.DiscardReason)
    }

    static let hudDelay = Duration.milliseconds(300)
    static let watchdogInterval: TimeInterval = 0.25

    package internal(set) var isRecording = false

    @ObservationIgnored let recorder: any AudioRecorder
    @ObservationIgnored let keyEventMonitor: any KeyEventMonitor
    @ObservationIgnored let keyboardState: any KeyboardState
    @ObservationIgnored let focusTracker: any FocusTracker
    @ObservationIgnored let sounds: any FeedbackSoundPlayer
    @ObservationIgnored let settings: SettingsModel
    @ObservationIgnored let permissions: PermissionMonitor
    @ObservationIgnored let speechModel: SpeechModelController
    @ObservationIgnored let vocabulary: VocabularyModel
    @ObservationIgnored let hud: HUDController
    @ObservationIgnored let keyRecorder: KeyRecorder
    @ObservationIgnored let queue: DictationQueue
    @ObservationIgnored var triggers = RecordingTriggers()
    @ObservationIgnored var watchdog = ReleaseWatchdog()
    @ObservationIgnored var lastRecordingID = RecordingID.none

    @ObservationIgnored var recording: ActiveRecording?

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
    func tick(_ event: PushToTalk.Event, at time: TimeInterval) {
        guard let recording,
              let action = triggers.handle(event, for: recording.purpose, at: time, settings: settings.settings)
        else { return }

        perform(RecordingTrigger(purpose: recording.purpose, key: recording.key, action: action), at: time)
    }

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

        if let recording, recording.key.isPressed(by: keyEvent) {
            watchdog.keyWasSeen()
        }

        for trigger in triggers.handle(keyEvent, settings: settings.settings) {
            perform(trigger, at: keyEvent.timestamp)
        }
    }

    private func perform(_ trigger: RecordingTrigger, at time: TimeInterval) {
        if trigger.action == .startRecording {
            if recording == nil {
                beginRecording(for: trigger)
            }

            return
        }

        guard recording?.purpose == trigger.purpose else { return }

        switch trigger.action {
        case .startRecording:
            break

        case .lockHandsFree:
            recording?.isHandsFree = true
            hud.lockHandsFree()

        case .finishRecording:
            endRecording(.finish(releasedAt: time))

        case let .discardRecording(reason):
            endRecording(.discard(reason))
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
