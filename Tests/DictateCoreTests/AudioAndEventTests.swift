@testable import DictateCore
import Foundation
import Testing

struct AudioLevelTests {
    @Test func rmsOfSilenceIsZero() {
        #expect(AudioLevel.rms([Float](repeating: 0, count: 100)) == 0)
        #expect(AudioLevel.rms([Float]()) == 0)
    }

    @Test func rmsOfConstantSignal() {
        #expect(abs(AudioLevel.rms([0.5, -0.5, 0.5, -0.5]) - 0.5) < 0.0001)
    }

    @Test func meterClampsToRange() {
        #expect(AudioLevel.meterValue(rms: 0) == 0)
        #expect(AudioLevel.meterValue(rms: 0.000_001) == 0)
        #expect(AudioLevel.meterValue(rms: 1) == 1)
        #expect(AudioLevel.meterValue(rms: 2) == 1)
    }

    @Test func meterIsMonotonic() {
        let quiet = AudioLevel.meterValue(rms: 0.01)
        let loud = AudioLevel.meterValue(rms: 0.1)
        #expect(quiet > 0)
        #expect(loud > quiet)
        #expect(loud < 1)
    }
}

struct SpeechSpanTests {
    /// 16 samples per "window" at a sample rate of 800 Hz.
    private func signal(silence lead: Int, loud: Int, silence tail: Int) -> [Float] {
        [Float](repeating: 0, count: lead * 16) + [Float](repeating: 0.5, count: loud * 16)
            + [Float](repeating: 0, count: tail * 16)
    }

    @Test func spanIgnoresLeadingAndTrailingSilence() throws {
        let samples = signal(silence: 10, loud: 25, silence: 7)
        let span = try #require(AudioLevel.speechSpan(of: samples, sampleRate: 800))
        #expect(abs(span - 0.5) < 0.0001)
    }

    @Test func gapsInsideSpeechCount() throws {
        let samples = signal(silence: 0, loud: 5, silence: 10) + signal(silence: 0, loud: 5, silence: 0)
        let span = try #require(AudioLevel.speechSpan(of: samples, sampleRate: 800))
        #expect(abs(span - 0.4) < 0.0001)
    }

    @Test func silenceHasNoSpan() {
        #expect(AudioLevel.speechSpan(of: signal(silence: 20, loud: 0, silence: 0), sampleRate: 800) == nil)
        #expect(AudioLevel.speechSpan(of: [], sampleRate: 800) == nil)
    }

    @Test func quietNoiseBelowThresholdIsNotSpeech() {
        let hiss = [Float](repeating: 0.001, count: 800) // -60 dBFS
        #expect(AudioLevel.speechSpan(of: hiss, sampleRate: 800) == nil)
    }
}

struct AppEventTests {
    @Test func roundTripThroughLog() throws {
        let events: [AppEvent] = [
            .ready,
            .hotkeyUnavailable,
            .recordingStarted(device: "BlackHole 2ch"),
            .recordingFinished(seconds: 1.5, samples: 24000, file: "/tmp/a.wav"),
            .recordingFinished(seconds: 2, samples: 32000, file: nil),
            .recordingDiscarded(.tooShort),
            .recordingDiscarded(.otherKeyPressed),
            .recordingDiscarded(.interrupted),
            .recordingFailed("no device"),
            .overlayShown,
            .overlayHidden,
            .tapReenabled,
            .recordingDiscarded(.modelNotReady),
            .modelReady(name: "openai_whisper-large-v3-v20240930_626MB", loadSeconds: 12.5),
            .transcribed(language: .ko, characters: 42, seconds: 1.25),
            .noSpeech,
            .transcriptionFailed("the model is not loaded"),
            .inserted(characters: 12, app: "com.apple.TextEdit", secureInputActive: false),
            .insertionSkipped(.secureField),
            .insertionSkipped(.focusChanged),
            .restoreSkipped("the clipboard holds more than 5 MB"),
        ]
        let log = try events.map { try $0.jsonLine() }.joined()
        #expect(AppEvent.parseLog(log) == events)
    }

    @Test func eachEventIsOneLine() throws {
        let line = try AppEvent.recordingFinished(seconds: 1, samples: 16000, file: "/tmp/x.wav").jsonLine()
        #expect(line.hasSuffix("\n"))
        #expect(line.dropLast().contains("\n") == false)
    }

    @Test func malformedLinesAreSkipped() throws {
        let log = try AppEvent.ready.jsonLine() + "{\"partial\n" + AppEvent.overlayShown.jsonLine()
        #expect(AppEvent.parseLog(log) == [.ready, .overlayShown])
    }
}

struct LaunchOptionsTests {
    @Test func parsesAllOptions() {
        let options = LaunchOptions(arguments: [
            "Dictate",
            "--report-file", "/tmp/r.json",
            "--event-log", "/tmp/e.jsonl",
            "--recording-dir", "/tmp/rec",
            "--input-device", "BlackHole 2ch",
            "--model", "openai_whisper-large-v3-v20240930",
            "--transcript-dir", "/tmp/tr",
        ], environment: ["DICTATE_E2E": "1"])
        #expect(options.reportFile == "/tmp/r.json")
        #expect(options.eventLog == "/tmp/e.jsonl")
        #expect(options.recordingDirectory == "/tmp/rec")
        #expect(options.inputDevice == "BlackHole 2ch")
        #expect(options.model == "openai_whisper-large-v3-v20240930")
        #expect(options.transcriptDirectory == "/tmp/tr")
    }

    @Test func transcriptDirectoryNeedsTheE2EEnvironment() {
        let arguments = ["Dictate", "--event-log", "/tmp/e.jsonl", "--transcript-dir", "/tmp/tr"]
        #expect(LaunchOptions(arguments: arguments, environment: [:]).transcriptDirectory == nil)
        #expect(LaunchOptions(arguments: arguments, environment: ["DICTATE_E2E": "0"]).transcriptDirectory == nil)
        #expect(LaunchOptions(arguments: arguments, environment: ["DICTATE_E2E": "1"]).transcriptDirectory == "/tmp/tr")
    }

    @Test func defaultsToNothing() {
        #expect(LaunchOptions(arguments: ["Dictate"]) == LaunchOptions(arguments: []))
        #expect(LaunchOptions(arguments: ["Dictate"]).inputDevice == nil)
    }
}
