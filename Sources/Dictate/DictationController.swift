import AVFoundation
import CoreGraphics
import DictateCore
import Foundation
import Observation

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

    /// Recording longer than this is stopped, as if the key had been released (a forgotten hold).
    static let maximumRecording: Double = 300
    /// The pill appears only after this long, so a quick Option+letter does not flash it.
    static let overlayDelay: Duration = .milliseconds(300)

    private struct Recording {
        let generation: Int
        let startedAt: Double
        var failed = false
        var overlayTask: Task<Void, Never>?
        var watchdog: Timer?
    }

    private enum Ending {
        case finish(seconds: Double)
        case discard(PushToTalk.DiscardReason)
    }

    private(set) var hotkeyStatus = HotkeyStatus.starting

    private let options: LaunchOptions
    private let eventLog: EventLogWriter
    private let recorder: AudioRecorder
    private let overlay = RecordingOverlay()
    private var pushToTalk = PushToTalk()
    private var monitor: HotkeyMonitor?
    private var recording: Recording?
    private var generation = 0
    private var askedForInputMonitoring = false

    init(options: LaunchOptions) {
        self.options = options
        eventLog = EventLogWriter(path: options.eventLog)
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
        Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.installHotkey() }
        }
    }

    private func handle(_ signal: KeyboardSignal, at time: Double) {
        switch pushToTalk.handle(signal, at: time) {
        case .startRecording: begin(at: time)
        case let .finishRecording(seconds): end(.finish(seconds: seconds))
        case let .discardRecording(reason): end(.discard(reason))
        case nil: break
        }
    }

    // MARK: Recording

    private func begin(at time: Double) {
        generation += 1
        let current = generation
        var active = Recording(generation: current, startedAt: time)
        active.overlayTask = Task { [weak self] in
            try? await Task.sleep(for: Self.overlayDelay)
            guard !Task.isCancelled else { return }
            self?.showOverlay(for: current)
        }
        active.watchdog = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkHotkeyStillHeld() }
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
        hideOverlay()
        let generation = ended.generation

        switch ending {
        case let .discard(reason):
            eventLog.log(.recordingDiscarded(reason))
            Task { _ = await recorder.stop(generation: generation) }
        case let .finish(seconds):
            Task { await finish(generation: generation, seconds: seconds, failed: ended.failed) }
        }
    }

    private func finish(generation: Int, seconds: Double, failed: Bool) async {
        let samples = await recorder.stop(generation: generation)
        guard !failed else { return }
        guard !samples.isEmpty else {
            eventLog.log(.recordingFailed("no audio was captured"))
            return
        }
        var file: String?
        if let directory = options.recordingDirectory {
            let url = URL(fileURLWithPath: directory)
            do {
                file = try await Task.detached { try RecordingStore.save(samples, in: url).path }.value
            } catch {
                eventLog.log(.recordingFailed("cannot save the recording: \(error.localizedDescription)"))
                return
            }
        }
        eventLog.log(.recordingFinished(seconds: seconds, samples: samples.count, file: file))
    }

    /// If the key-up went missing (the tap was off, or the event was eaten), the hardware state
    /// still tells the truth. `hidSystemState` rather than the session state: it also reflects
    /// events posted synthetically, which the E2E suite relies on.
    private func checkHotkeyStillHeld() {
        guard let active = recording else { return }
        let now = uptimeSeconds()
        let flags = CGEventSource.flagsState(.hidSystemState).rawValue
        if flags & Hotkey.rightOptionDeviceFlag == 0 || now - active.startedAt >= Self.maximumRecording {
            handle(.hotkeyUp, at: now)
        }
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
        overlay.show { meter.value }
        eventLog.log(.overlayShown)
    }

    private func hideOverlay() {
        guard overlay.isVisible else { return }
        overlay.hide()
        eventLog.log(.overlayHidden)
    }
}
