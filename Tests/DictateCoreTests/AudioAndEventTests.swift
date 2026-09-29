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
        ])
        #expect(options.reportFile == "/tmp/r.json")
        #expect(options.eventLog == "/tmp/e.jsonl")
        #expect(options.recordingDirectory == "/tmp/rec")
        #expect(options.inputDevice == "BlackHole 2ch")
    }

    @Test func defaultsToNothing() {
        #expect(LaunchOptions(arguments: ["Dictate"]) == LaunchOptions(arguments: []))
        #expect(LaunchOptions(arguments: ["Dictate"]).inputDevice == nil)
    }
}
