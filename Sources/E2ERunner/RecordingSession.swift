import AudioDevices
import AVFoundation
import Carbon.HIToolbox
import DictateCore
import Foundation

/// A check's way to say "not passing" from deep inside helpers; `PushToTalkChecks.run` turns it
/// into an `Outcome`.
enum Verdict: Error {
    case fail(String)
    case blocked(String)
}

/// What a check needs from the machine, verified once per check so a missing piece is reported as
/// BLOCKED (something the user can fix) instead of a confusing FAIL further on.
struct Environment {
    let dictatePID: pid_t
    let blackHole: AudioDevice
}

/// One hold of the hotkey that recorded audio, as the app reported it and as the file shows it.
struct Capture {
    /// Seconds from posting the key press to the app's first audio buffer.
    let latency: Double
    let device: String
    /// Hold time the app reported.
    let seconds: Double
    let samples: [Float]
}

/// The payload of `AppEvent.recordingFinished`.
private struct FinishedEvent {
    let seconds: Double
    let samples: Int
    let file: String?
}

/// Reads mono 16 kHz WAV files, the format the app writes and the fixtures use.
enum WAVReader {
    static func samples(at url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        guard format.sampleRate == 16000, format.channelCount == 1 else {
            let actual = "\(Int(format.sampleRate)) Hz x\(format.channelCount)"
            throw Verdict.fail("\(url.lastPathComponent) is \(actual), expected 16 kHz mono")
        }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw Verdict.fail("cannot allocate a buffer for \(url.lastPathComponent)")
        }
        try file.read(into: buffer)
        guard let channel = buffer.floatChannelData?[0] else { throw Verdict.fail("no samples in \(url.lastPathComponent)") }
        return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    }
}

/// Drives one hold of right Option against the running app and collects what happened.
@MainActor
struct RecordingSession {
    let dictate: AppLauncher
    let log: EventLog
    let keyboard: KeyboardDriver

    func environment() throws -> Environment {
        guard AXIsProcessTrusted() else {
            throw Verdict.blocked("Accessibility not granted to your terminal app (needed to post key events)")
        }
        if IsSecureEventInputEnabled() {
            throw Verdict.blocked(
                "Secure keyboard entry is on (Terminal → Secure Keyboard Entry, or a password field has focus): "
                    + "synthetic keys are not delivered to event taps"
            )
        }
        guard let pid = dictate.runningApplication?.processIdentifier else { throw Verdict.fail("Dictate is not running") }
        guard let blackHole = AudioDevices.find(AudioDevices.blackHoleUID, direction: .output)
            ?? AudioDevices.find("BlackHole 2ch", direction: .output)
        else {
            throw Verdict.blocked("BlackHole 2ch is not installed: brew install blackhole-2ch")
        }
        try requireHotkey()
        return Environment(dictatePID: pid, blackHole: blackHole)
    }

    /// Waits for the app's `ready`; `hotkeyUnavailable` instead means a missing permission.
    func requireHotkey(timeout: TimeInterval = 5) throws {
        let ready = waitUntil(timeout: timeout) { log.events.contains(.ready) }
        guard ready else {
            if log.events.contains(.hotkeyUnavailable) {
                throw Verdict.blocked("Dictate.app cannot listen for the hotkey: grant it Input Monitoring (menu bar icon)")
            }
            throw Verdict.fail("Dictate logged neither ready nor hotkeyUnavailable within \(Int(timeout)) s")
        }
    }

    /// Holds right Option, waits for the microphone to go live, then either plays `fixture` into
    /// BlackHole or stays silent for `silence` seconds, and releases.
    ///
    /// `beforeRelease` runs after the audio, with the key still down: a check that needs a condition to
    /// hold at the moment of release (the right app in front) asserts it there.
    func capture(
        playing playback: PreparedPlayback?,
        silence: TimeInterval,
        beforeRelease: () throws -> Void = {}
    ) throws -> Capture {
        let baseline = log.baseline()
        let pressed = ProcessInfo.processInfo.systemUptime
        var latency = 0.0
        var device = ""
        try keyboard.holding(.rightOption) {
            guard let started = try wait(since: baseline, timeout: 3, { event -> String? in
                if case let .recordingStarted(device) = event {
                    device
                } else {
                    nil
                }
            }) else {
                throw Verdict.fail("no recordingStarted within 3 s of the key press" + failureHint(since: baseline))
            }
            latency = ProcessInfo.processInfo.systemUptime - pressed
            device = started
            if let playback {
                // Released the moment playback ends, so a cut-off tail shows up in the measurements.
                do {
                    try playback.play()
                } catch {
                    throw Verdict.fail("\(error)")
                }
            } else {
                Thread.sleep(forTimeInterval: silence)
            }
            try beforeRelease()
        }
        return try finishedCapture(since: baseline, latency: latency, device: device)
    }

    private func finishedCapture(since baseline: EventLog.Baseline, latency: Double, device: String) throws -> Capture {
        guard let finished = try wait(since: baseline, timeout: 5, { event -> FinishedEvent? in
            if case let .recordingFinished(seconds, samples, file) = event {
                FinishedEvent(seconds: seconds, samples: samples, file: file)
            } else {
                nil
            }
        }) else {
            throw Verdict.fail("no recordingFinished within 5 s of the release" + failureHint(since: baseline))
        }
        guard let path = finished.file, log.newFiles(since: baseline).count == 1 else {
            throw Verdict.fail("expected exactly one new WAV file, found \(log.newFiles(since: baseline).sorted())")
        }
        let samples = try WAVReader.samples(at: URL(fileURLWithPath: path))
        guard samples.count == finished.samples else {
            throw Verdict.fail("file holds \(samples.count) samples, the log says \(finished.samples)")
        }
        return Capture(latency: latency, device: device, seconds: finished.seconds, samples: samples)
    }

    /// Like `EventLog.waitForNew`, but a `recordingFailed` from the app is an immediate FAIL with its message.
    func wait<T>(since baseline: EventLog.Baseline, timeout: TimeInterval, _ match: (AppEvent) -> T?) throws -> T? {
        var found: T?
        var failure: String?
        _ = waitUntil(timeout: timeout, interval: 0.01) {
            let events = log.newEvents(since: baseline)
            failure = events.lazy.compactMap { event -> String? in
                if case let .recordingFailed(message) = event {
                    message
                } else {
                    nil
                }
            }.first
            found = events.lazy.compactMap(match).first
            return found != nil || failure != nil
        }
        if let failure {
            throw Verdict.fail("the app reported recordingFailed: \(failure)")
        }
        return found
    }

    /// Waits for a new event satisfying `predicate`; see `wait(since:timeout:_:)`.
    func waitFor(since baseline: EventLog.Baseline, timeout: TimeInterval, where predicate: (AppEvent) -> Bool) throws -> Bool {
        try wait(since: baseline, timeout: timeout) { predicate($0) ? $0 : nil } != nil
    }

    /// What the app logged since `baseline`, for the failure message: without it a timeout says nothing.
    private func failureHint(since baseline: EventLog.Baseline) -> String {
        " (app logged: \(log.newEvents(since: baseline)))"
    }
}
