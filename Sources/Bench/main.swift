import DictateCore
import Foundation
import Transcription

// `make bench`: runs every fixture through the recogniser with automatic language detection and
// checks the accuracy and speed gates. Exit code: 0 passed, 1 a gate missed, 2 the model or the
// fixtures are not there (nothing is downloaded here). Run from the repository root.
// Usage: Bench [--model <variant>] [--no-prompt] [--report-dir <dir>]

let model = argumentValue(after: "--model") ?? ModelStore.defaultModel
let usesStylePrompt = !CommandLine.arguments.contains("--no-prompt")
let reportDirectory = URL(fileURLWithPath: argumentValue(after: "--report-dir") ?? "bench/reports")
let base = ModelStore.defaultBaseDirectory

guard ModelStore.isInstalled(model, in: base) else {
    print("BLOCKED: the model \(model) is not downloaded: run `make model MODEL=\(model)`")
    exit(2)
}

let clips: (say: [Clip], fleurs: [Clip])
do {
    clips = try ClipLoader.load(fixtures: URL(fileURLWithPath: "fixtures"))
} catch {
    print("BLOCKED: \(error)")
    exit(2)
}

do {
    let transcriber = Transcriber(model: model, baseDirectory: base, usesStylePrompt: usesStylePrompt)
    print("loading \(model)…")
    let loadSeconds = try await transcriber.load()
    let all = clips.say + clips.fleurs
    // The first inference after loading is slower than the rest; keep it out of the numbers.
    if let first = all.first {
        _ = try await transcriber.transcribe(samples: first.samples, language: nil)
    }

    var results: [ClipResult] = []
    for clip in all {
        let result = try await measure(clip, with: transcriber)
        let error = String(format: "%.1f", result.characterErrorRate * 100)
        let times = String(format: "detect %.2f s, transcribe %.2f s", result.detectSeconds, result.transcribeSeconds)
        print("\(clip.id): \(result.detected?.rawValue ?? "none"), error \(error) %, \(times)")
        results.append(result)
    }

    let summary = BenchSummary(
        model: model, usesStylePrompt: usesStylePrompt, loadSeconds: loadSeconds,
        residentMegabytes: residentMegabytes(), results: results
    )
    let report = try save(summary.markdown, in: reportDirectory)
    print("\n" + summary.markdown + "\nReport: \(report.path)")
    exit(summary.failures.isEmpty ? 0 : 1)
} catch {
    print("bench failed: \(error)")
    exit(1)
}

/// Transcribes `clip` (three times if it is one of the latency clips) and scores the last text.
func measure(_ clip: Clip, with transcriber: Transcriber) async throws -> ClipResult {
    var transcripts: [Transcript] = []
    for _ in 0 ..< (clip.isLong ? 3 : 1) {
        if let transcript = try await transcriber.transcribe(samples: clip.samples, language: nil) {
            transcripts.append(transcript)
        }
    }
    guard let last = transcripts.last else {
        return ClipResult(
            clip: clip, detected: nil, probability: nil, characterErrorRate: 1, detectSeconds: 0, transcribeSeconds: 0
        )
    }
    let rate = TextMetrics.cer(
        reference: clip.reference, alternatives: clip.alternatives, hypothesis: last.text, language: clip.language
    )
    var result = ClipResult(
        clip: clip, detected: last.language, probability: last.languageProbability, characterErrorRate: rate,
        detectSeconds: median(transcripts.map(\.detectSeconds)),
        transcribeSeconds: median(transcripts.map(\.transcribeSeconds))
    )
    if clip.source != .say {
        let expected = PunctuationMetrics.counts(in: clip.reference)
        result.style = ClipResult.Style(
            reference: expected,
            matched: PunctuationMetrics.matched(reference: expected, hypothesis: PunctuationMetrics.counts(in: last.text)),
            referenceCase: PunctuationMetrics.startingCase(of: clip.reference),
            hypothesisCase: PunctuationMetrics.startingCase(of: last.text)
        )
    }
    return result
}

func median(_ values: [Double]) -> Double {
    values.sorted()[values.count / 2]
}

/// Writes the report as `<date>-<model>.md`; the folder is git-ignored.
func save(_ report: String, in directory: URL) throws -> URL {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmm"
    let variant = usesStylePrompt ? "" : "-noprompt"
    let url = directory.appendingPathComponent("\(formatter.string(from: Date()))-\(model)\(variant).md")
    try report.write(to: url, atomically: true, encoding: .utf8)
    return url
}

/// Physical memory the process holds (`phys_footprint`), which is what Activity Monitor calls Memory.
func residentMegabytes() -> Double {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let status = withUnsafeMutablePointer(to: &info) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    return status == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : 0
}
