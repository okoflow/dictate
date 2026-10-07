import AVFoundation
import CoreGraphics
import DictateCore
import Foundation
import Observation
import Transcription

/// Connects the hotkey to the microphone and the overlay: hold right Option to record, release to
/// stop. Owns the whole push-to-talk flow; the parts (`PushToTalk`, `AudioRecorder`, ...) each do
/// one thing.
@MainActor
@Observable
final class DictationController {
    enum HotkeyStatus {
        case starting
        case ready
        /// The event tap cannot be installed, almost always because Input Monitoring is not granted.
        case unavailable
    }

    /// The pill appears only after this long, so a quick Option+letter does not flash it.
    static let overlayDelay: Duration = .milliseconds(300)

    private struct Recording {
        let generation: Int
        var failed = false
        /// Where the focus was when the key went down: the dictation is for that field.
        var target: FocusSnapshot?
        /// Pressed before the speech model was ready: nothing is recorded, the press only has to be waited out.
        var rejected = false
        var overlayTask: Task<Void, Never>?
        var watchdog: Timer?
    }

    private enum Ending {
        case finish(seconds: Double, releasedAt: Double)
        case discard(PushToTalk.DiscardReason)
    }

    private(set) var hotkeyStatus = HotkeyStatus.starting
    let models: ModelController
    let language: LanguageSettings
    let mode: ModeSettings
    let apiKey = APIKeySettings()
    let insertion = InsertionSettings()
    let lastTranscript = LastTranscript()
    let history: HistoryStore
    let appModes: AppModeSettings
    let vocabulary: VocabularyStore

    let options: LaunchOptions
    let eventLog: EventLogWriter
    private let recorder: AudioRecorder
    let overlay = Overlay()
    let pipeline: TranscriptionPipeline
    private var pushToTalk = PushToTalk()
    private var releaseWatchdog = ReleaseWatchdog()
    private var monitor: HotkeyMonitor?
    var modeHotkey: ModeHotkey?
    private var recording: Recording?
    private var generation = 0
    private var askedForInputMonitoring = false

    init(options: LaunchOptions) {
        self.options = options
        language = LanguageSettings(override: options.language)
        mode = ModeSettings(override: options.mode)
        eventLog = EventLogWriter(path: options.eventLog)
        appModes = AppModeSettings(override: options.appModes)
        history = HistoryStore(path: options.historyFile)
        vocabulary = VocabularyStore(path: options.dictionaryFile, eventLog: eventLog)
        models = ModelController(model: options.model ?? ModelStore.defaultModel, eventLog: eventLog)
        pipeline = TranscriptionPipeline(
            transcriber: models.transcriber,
            options: options,
            eventLog: eventLog,
            status: overlay,
            inserter: Inserter(eventLog: eventLog),
            insertion: insertion,
            lastTranscript: lastTranscript,
            history: history,
            recordingPillIsVisible: { [overlay] in overlay.isRecording }
        )
        let (events, continuation) = AsyncStream.makeStream(of: (Int, RecorderEvent).self)
        recorder = AudioRecorder { continuation.yield(($0, $1)) }
        Task { [weak self] in
            for await (generation, event) in events {
                self?.recorderReported(event, generation: generation)
            }
        }
        monitor = HotkeyMonitor(
            onSignal: { [weak self] signal, time in self?.handle(signal, at: time) },
            onTapReenabled: { [weak self] in self?.eventLog.log(.tapReenabled) },
            onHotkeyBitSeen: { [weak self] in self?.releaseWatchdog.sawHotkeyEvent() }
        )
        installHotkey()
        installModeSwitching()
        models.onReady = { [overlay] in overlay.show(message: "Ready") }
        models.start()
    }

    // MARK: Hotkey

    /// Retries every 2 s until Input Monitoring is granted, because macOS sends no notification.
    private func installHotkey() {
        if monitor?.start() == true {
            hotkeyStatus = .ready
            eventLog.log(.ready)
            return
        }
        if hotkeyStatus != .unavailable {
            hotkeyStatus = .unavailable
            eventLog.log(.hotkeyUnavailable)
        }
        if !askedForInputMonitoring {
            askedForInputMonitoring = true
            _ = CGRequestListenEventAccess()
        }
        _ = Timer.commonModeTimer(interval: 2, repeats: false) { [weak self] in self?.installHotkey() }
    }

    private func handle(_ signal: KeyboardSignal, at time: Double) {
        switch pushToTalk.handle(signal, at: time) {
        case .startRecording: begin()
        case let .finishRecording(seconds): end(.finish(seconds: seconds, releasedAt: time))
        case let .discardRecording(reason): end(.discard(reason))
        case nil: break
        }
    }

    // MARK: Recording

    private func begin() {
        generation += 1
        let current = generation
        var active = Recording(generation: current)
        releaseWatchdog.reset()
        active.watchdog = Timer.commonModeTimer(interval: 0.25, repeats: true) { [weak self] in
            self?.checkHotkeyStillHeld()
        }
        guard models.state.isReady else {
            // The watchdog still runs, so a lost key-up does not leave the state machine holding.
            active.rejected = true
            recording = active
            eventLog.log(.recordingDiscarded(.modelNotReady))
            overlay.show(message: models.state.notReadyMessage)
            return
        }
        active.overlayTask = Task { [weak self] in
            try? await Task.sleep(for: Self.overlayDelay)
            guard !Task.isCancelled else { return }
            self?.showOverlay(for: current)
        }
        recording = active

        if let denied = microphoneProblem() {
            failRecording(denied)
            return
        }
        let device = options.inputDevice
        Task { await recorder.start(generation: current, deviceName: device) }
        // After the recorder is on its way, and not inside the event tap's callback: reading the focus
        // asks another app over Accessibility and can take a moment.
        Task { [weak self] in self?.captureTarget(generation: current) }
    }

    private func end(_ ending: Ending) {
        guard let ended = recording else { return }
        recording = nil
        ended.overlayTask?.cancel()
        ended.watchdog?.invalidate()
        guard !ended.rejected else { return }
        hideOverlay()
        let generation = ended.generation

        switch ending {
        case let .discard(reason):
            eventLog.log(.recordingDiscarded(reason))
            Task { _ = await recorder.stop(generation: generation) }
        case let .finish(seconds, releasedAt):
            Task {
                await finish(
                    generation: generation, seconds: seconds, releasedAt: releasedAt, failed: ended.failed, target: ended.target
                )
            }
        }
    }

    /// Every press ends with exactly one `recordingFinished` or `recordingDiscarded`; a failure is
    /// reported by `recordingFailed` first and then still closes the press as discarded.
    private func finish(generation: Int, seconds: Double, releasedAt: Double, failed: Bool, target: FocusSnapshot?) async {
        let samples = await recorder.stop(generation: generation, releasedAt: failed ? nil : releasedAt)
        guard !failed else {
            eventLog.log(.recordingDiscarded(.interrupted))
            return
        }
        guard !samples.isEmpty else {
            // A release can overtake the recorder's own failure report; keep the real reason.
            let reason = await recorder.failureMessage(generation: generation)
            eventLog.log(.recordingFailed(reason ?? "no audio was captured"))
            eventLog.log(.recordingDiscarded(.interrupted))
            return
        }
        var file: String?
        if let directory = options.recordingDirectory {
            let url = URL(fileURLWithPath: directory)
            do {
                file = try await Task.detached { try RecordingStore.save(samples, in: url).path }.value
            } catch {
                eventLog.log(.recordingFailed("cannot save the recording: \(error.localizedDescription)"))
                eventLog.log(.recordingDiscarded(.interrupted))
                return
            }
        }
        eventLog.log(.recordingFinished(seconds: seconds, samples: samples.count, file: file))
        submit(samples, target: target ?? FocusProbe.current())
    }

    private func microphoneProblem() -> String? {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .denied, .restricted: "microphone permission is not granted"
        default: nil
        }
    }

    private func recorderReported(_ event: RecorderEvent, generation: Int) {
        guard recording?.generation == generation else { return }
        switch event {
        case let .started(device):
            eventLog.log(.recordingStarted(device: device))
        case let .failed(message):
            failRecording(message)
        }
    }

    private func failRecording(_ message: String) {
        guard var active = recording, !active.failed else { return }
        active.failed = true
        recording = active
        eventLog.log(.recordingFailed(message))
        hideOverlay()
        let generation = active.generation
        Task { _ = await recorder.stop(generation: generation) }
    }
}

extension DictationController {
    private func captureTarget(generation: Int) {
        guard var active = recording, active.generation == generation else { return }
        active.target = FocusProbe.current()
        recording = active
    }

    /// Runs every 250 ms while holding, as a safety net for a key-up that never reaches the event tap (the
    /// tap was off, or the event was eaten). The tap is the authority: the keyboard state words are only
    /// intermittently in step with the real keyboard, so one poll that finds the key up proves nothing.
    /// `ReleaseWatchdog` declares the release after four such polls in a row (a second), counted again
    /// from zero whenever the key shows up; the recording then ends at the time of the first of them.
    /// A poll that finds the key held also lets the state machine end a hold that runs past the maximum.
    private func checkHotkeyStillHeld() {
        guard recording != nil else { return }
        let now = uptimeSeconds()
        let held = Hotkey.isStillHeld(
            hidFlags: CGEventSource.flagsState(.hidSystemState).rawValue,
            sessionFlags: CGEventSource.flagsState(.combinedSessionState).rawValue
        )
        switch releaseWatchdog.poll(held: held, at: now) {
        case .holding:
            handle(.tick, at: now)
        case let .released(since):
            eventLog.log(.watchdogReleased)
            handle(.hotkeyUp, at: since)
        }
    }

    func prepareToQuit() async {
        await pipeline.finishPendingInsertions()
    }

    // MARK: Overlay

    private func showOverlay(for generation: Int) {
        guard let active = recording, active.generation == generation, !active.failed, !overlay.isRecording else { return }
        let meter = recorder.meter
        overlay.showRecording { meter.value }
        eventLog.log(.overlayShown)
    }

    private func hideOverlay() {
        guard overlay.isRecording else { return }
        overlay.hideRecording()
        eventLog.log(.overlayHidden)
        pipeline.recordingPillHidden()
    }
}
