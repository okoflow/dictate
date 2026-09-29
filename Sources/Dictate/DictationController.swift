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
    let language = LanguageSettings()

    private let options: LaunchOptions
    private let eventLog: EventLogWriter
    private let recorder: AudioRecorder
    private let overlay = RecordingOverlay()
    private let status = StatusOverlay()
    private let pipeline: TranscriptionPipeline
    private var pushToTalk = PushToTalk()
    private var monitor: HotkeyMonitor?
    private var recording: Recording?
    private var generation = 0
    private var askedForInputMonitoring = false

    init(options: LaunchOptions) {
        self.options = options
        eventLog = EventLogWriter(path: options.eventLog)
        models = ModelController(model: options.model ?? ModelStore.defaultModel, eventLog: eventLog)
        let pill = overlay
        pipeline = TranscriptionPipeline(
            transcriber: models.transcriber,
            options: options,
            eventLog: eventLog,
            status: status,
            recordingPillIsVisible: { pill.isVisible }
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
            onTapReenabled: { [weak self] in self?.eventLog.log(.tapReenabled) }
        )
        installHotkey()
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
        active.watchdog = Timer.commonModeTimer(interval: 0.25, repeats: true) { [weak self] in
            self?.checkHotkeyStillHeld()
        }
        guard models.state.isReady else {
            // The watchdog still runs, so a lost key-up does not leave the state machine holding.
            active.rejected = true
            recording = active
            eventLog.log(.recordingDiscarded(.modelNotReady))
            status.show(message: "Model not ready")
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
            Task { await finish(generation: generation, seconds: seconds, releasedAt: releasedAt, failed: ended.failed) }
        }
    }

    /// Every press ends with exactly one `recordingFinished` or `recordingDiscarded`; a failure is
    /// reported by `recordingFailed` first and then still closes the press as discarded.
    private func finish(generation: Int, seconds: Double, releasedAt: Double, failed: Bool) async {
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
        pipeline.submit(samples: samples, language: language.preference.language)
    }

    /// Runs every 250 ms while holding. If the key-up went missing (the tap was off, or the event was
    /// eaten) the keyboard state still tells the truth; the key counts as released only when *both*
    /// the HID state (which sees synthetic events, as in the E2E suite) and the session state (which
    /// sees keys injected by remote-control tools) have lost the right Option bit. It also lets
    /// the state machine end a hold that runs past the maximum length.
    private func checkHotkeyStillHeld() {
        guard recording != nil else { return }
        let now = uptimeSeconds()
        let held = Hotkey.isStillHeld(
            hidFlags: CGEventSource.flagsState(.hidSystemState).rawValue,
            sessionFlags: CGEventSource.flagsState(.combinedSessionState).rawValue
        )
        handle(held ? .tick : .hotkeyUp, at: now)
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

    // MARK: Overlay

    private func showOverlay(for generation: Int) {
        guard let active = recording, active.generation == generation, !active.failed, !overlay.isVisible else { return }
        let meter = recorder.meter
        status.hide()
        overlay.show { meter.value }
        eventLog.log(.overlayShown)
    }

    private func hideOverlay() {
        guard overlay.isVisible else { return }
        overlay.hide()
        eventLog.log(.overlayHidden)
        pipeline.recordingPillHidden()
    }
}
