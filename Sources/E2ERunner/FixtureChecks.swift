import AVFoundation
import Foundation

struct FixtureEntry: Decodable {
    let id: String
    let language: String
}

/// Verifies the generated speech fixtures: every manifest entry has a real, non-silent,
/// 16 kHz mono WAV, and all three languages are covered.
enum FixtureChecks {
    static let requiredLanguages: Set = ["ru", "en", "ko"]

    static func run(manifestURL: URL, generatedDirectory: URL) -> Outcome {
        let entries: [FixtureEntry]
        do {
            entries = try JSONDecoder().decode([FixtureEntry].self, from: Data(contentsOf: manifestURL))
        } catch {
            return .fail("cannot read \(manifestURL.path): \(error)")
        }

        let missingLanguages = requiredLanguages.subtracting(entries.map(\.language))
        if !missingLanguages.isEmpty {
            return .fail("manifest has no fixtures for: \(missingLanguages.sorted().joined(separator: ", "))")
        }

        var problems: [String] = []
        for entry in entries {
            let url = generatedDirectory.appendingPathComponent("\(entry.id).wav")
            if let problem = validate(wavAt: url) {
                problems.append("\(entry.id): \(problem)")
            }
        }
        if problems.isEmpty {
            return .pass
        }
        if problems.count == entries.count, !FileManager.default.fileExists(atPath: generatedDirectory.path) {
            return .blocked("fixtures not generated yet: run `make fixtures`")
        }
        return .fail(problems.joined(separator: "; "))
    }

    /// Returns a description of what is wrong with the file, or `nil` if it is a usable fixture.
    static func validate(wavAt url: URL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return "missing" }
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            guard format.sampleRate == 16000, format.channelCount == 1 else {
                return "expected 16 kHz mono, got \(Int(format.sampleRate)) Hz x\(format.channelCount)"
            }
            let seconds = Double(file.length) / format.sampleRate
            guard seconds >= 1 else { return "too short (\(String(format: "%.2f", seconds)) s)" }
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)) else {
                return "cannot allocate buffer"
            }
            try file.read(into: buffer)
            let level = rms(buffer)
            return level > 0.005 ? nil : "silent (rms \(String(format: "%.4f", level)))"
        } catch {
            return "unreadable: \(error.localizedDescription)"
        }
    }

    static func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for index in 0 ..< Int(buffer.frameLength) {
            sum += samples[index] * samples[index]
        }
        return (sum / Float(buffer.frameLength)).squareRoot()
    }
}
