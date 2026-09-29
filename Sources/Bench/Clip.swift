import AVFoundation
import DictateCore
import Foundation

/// One recording to run through the recogniser, with what it should say.
struct Clip {
    enum Source: String {
        case say
        case fleurs
        /// Four FLEURS clips joined into one recording of 30 s or more, to exercise the long-audio path.
        case concat
    }

    let id: String
    let language: Language
    let samples: [Float]
    let reference: String
    let alternatives: [String]
    let tags: [String]
    let source: Source

    var seconds: Double {
        Double(samples.count) / 16000
    }

    /// Clean synthetic speech that gates the character error rate.
    var isCleanPlain: Bool {
        source == .say && tags.contains("plain") && !tags.contains("noisy")
    }

    var isLong: Bool {
        tags.contains("long")
    }
}

enum ClipLoader {
    struct Missing: Error, CustomStringConvertible {
        let description: String
    }

    /// Every `say` clip of the manifest, and the FLEURS clips if `fixtures/private` has any.
    static func load(fixtures: URL) throws -> (say: [Clip], fleurs: [Clip]) {
        let manifest = try Fixture.load(from: fixtures.appendingPathComponent("manifest.json"))
        let say = try manifest.map { fixture in
            let url = fixtures.appendingPathComponent("generated/\(fixture.id).wav")
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw Missing(description: "\(url.path) is missing: run `make fixtures`")
            }
            return try Clip(
                id: fixture.id, language: fixture.language, samples: samples(at: url), reference: fixture.text,
                alternatives: fixture.alternatives, tags: fixture.tags, source: .say
            )
        }
        let fleurs = try fleursClips(in: fixtures.appendingPathComponent("private"))
        return (say, fleurs + concatenations(of: fleurs))
    }

    /// One long recording per language from its first four FLEURS clips, half a second apart.
    private static func concatenations(of clips: [Clip]) -> [Clip] {
        Language.allCases.compactMap { language in
            let parts = clips.filter { $0.language == language && $0.source == .fleurs }.prefix(4)
            guard parts.count == 4 else { return nil }
            let gap = [Float](repeating: 0, count: 8000)
            return Clip(
                id: "fleurs-concat-\(language.rawValue)", language: language,
                samples: Array(parts.map { $0.samples + gap }.joined()),
                reference: parts.map(\.reference).joined(separator: " "), alternatives: [], tags: ["concat"], source: .concat
            )
        }
    }

    private static func fleursClips(in directory: URL) throws -> [Clip] {
        try Language.allCases.flatMap { language in
            try (1 ... 5).compactMap { number -> Clip? in
                let audio = directory.appendingPathComponent("\(language.rawValue)-\(number).wav")
                let text = directory.appendingPathComponent("\(language.rawValue)-\(number).txt")
                let present = [audio, text].allSatisfy { FileManager.default.fileExists(atPath: $0.path) }
                guard present else { return nil }
                return try Clip(
                    id: "fleurs-\(language.rawValue)-\(number)", language: language, samples: samples(at: audio),
                    reference: String(contentsOf: text, encoding: .utf8), alternatives: [], tags: ["real"], source: .fleurs
                )
            }
        }
    }

    private static func samples(at url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        guard format.sampleRate == 16000, format.channelCount == 1,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length))
        else {
            throw Missing(description: "\(url.lastPathComponent) is not a 16 kHz mono WAV")
        }
        try file.read(into: buffer)
        guard let channel = buffer.floatChannelData?[0] else {
            throw Missing(description: "\(url.lastPathComponent) has no samples")
        }
        return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    }
}
