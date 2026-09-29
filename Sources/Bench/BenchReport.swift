import DictateCore
import Foundation

/// What the recogniser did with one clip. Text is never kept, so a report cannot leak it.
struct ClipResult {
    let clip: Clip
    /// `nil` when nothing was recognised.
    let detected: Language?
    let probability: Double?
    let characterErrorRate: Double
    /// Median over the runs (three for the long clips, one for the others).
    let detectSeconds: Double
    let transcribeSeconds: Double

    var languageCorrect: Bool {
        detected == clip.language
    }
}

/// The numbers of one `make bench` run and the gates they are judged by.
struct BenchSummary {
    static let maximumCleanCER: [Language: Double] = [.ru: 0.10, .en: 0.10, .ko: 0.15]
    /// Language detection may miss once in the set.
    static let allowedLanguageMisses = 1
    static let goalSeconds = 1.0
    static let gateSeconds = 3.0

    let model: String
    let loadSeconds: Double
    let residentMegabytes: Double
    let results: [ClipResult]

    private var fleursIsComplete: Bool {
        results.filter { $0.clip.source == .fleurs }.count == Language.allCases.count * 5
    }

    /// All `say` clips, and the FLEURS ones only when all 15 are there, so the set does not change with a partial download.
    var languageSet: [ClipResult] {
        results.filter { $0.clip.source == .say || fleursIsComplete }
    }

    var languageMisses: Int {
        languageSet.count { !$0.languageCorrect }
    }

    var longClips: [ClipResult] {
        results.filter(\.clip.isLong)
    }

    func meanCER(of language: Language, where include: (Clip) -> Bool) -> Double? {
        let rates = results.filter { $0.clip.language == language && include($0.clip) }.map(\.characterErrorRate)
        return rates.isEmpty ? nil : rates.reduce(0, +) / Double(rates.count)
    }

    /// Reasons the run misses a gate; empty when it passes.
    var failures: [String] {
        var failures: [String] = []
        for language in Language.allCases {
            guard let rate = meanCER(of: language, where: \.isCleanPlain), let limit = Self.maximumCleanCER[language] else {
                failures.append("no clean plain fixtures for \(language.rawValue)")
                continue
            }
            if rate > limit {
                failures.append("\(language.rawValue) clean CER \(percent(rate)) > \(percent(limit))")
            }
        }
        if fleursIsComplete {
            for language in Language.allCases {
                guard let rate = meanCER(of: language, where: { $0.source == .fleurs }),
                      let limit = Self.maximumCleanCER[language], rate > limit else { continue }
                failures.append("\(language.rawValue) FLEURS CER \(percent(rate)) > \(percent(limit))")
            }
        }
        if languageMisses > Self.allowedLanguageMisses {
            let allowed = Self.allowedLanguageMisses
            failures.append("language id missed \(languageMisses) of \(languageSet.count) (allowed \(allowed))")
        }
        for result in longClips where result.transcribeSeconds > Self.gateSeconds {
            let took = seconds(result.transcribeSeconds)
            failures.append("\(result.clip.id) took \(took) to transcribe (gate \(Int(Self.gateSeconds)) s)")
        }
        return failures
    }

    var markdown: String {
        let header = [
            "# Bench report", "",
            "Model `\(model)`, run \(Date().formatted(.iso8601)), \(Self.machine)", "",
            "Model load: \(seconds(loadSeconds)). Memory after the run: \(Int(residentMegabytes)) MB.", "",
        ]
        let verdict = failures.isEmpty ? "**PASS**" : "**FAIL**: " + failures.joined(separator: "; ")
        let sections = errorRateSection + languageSection + latencySection + clipSection
        return (header + sections + [verdict, ""]).joined(separator: "\n")
    }

    private var errorRateSection: [String] {
        var lines = [
            "## Character error rate", "",
            "| Language | Clean plain (gated) | Noisy | Long | FLEURS (gated when all 15 are present) |", "|---|---|---|---|---|",
        ]
        for language in Language.allCases {
            let cells = [
                meanCER(of: language, where: \.isCleanPlain),
                meanCER(of: language) { $0.source == .say && $0.tags.contains("noisy") },
                meanCER(of: language, where: \.isLong),
                meanCER(of: language) { $0.source == .fleurs },
            ].map { $0.map(percent) ?? "-" }
            let limit = Self.maximumCleanCER[language].map { " (limit \(percent($0)))" } ?? ""
            lines.append("| \(language.rawValue) | \(cells[0])\(limit) | \(cells[1]) | \(cells[2]) | \(cells[3]) |")
        }
        return lines + [""]
    }

    private var languageSection: [String] {
        let right = languageSet.count - languageMisses
        let fleurs = fleursIsComplete ? "includes all 15 FLEURS clips" : "FLEURS not included (not all 15 clips present)"
        return [
            "## Language identification", "",
            "\(right) of \(languageSet.count) right (misses allowed: \(Self.allowedLanguageMisses)); \(fleurs).", "",
        ]
    }

    private var latencySection: [String] {
        var lines = [
            "## Latency on the ~10 s clips (median of 3, warm)", "",
            "| Clip | Audio | Detect | Transcribe | Goal ≤ \(Int(Self.goalSeconds)) s |", "|---|---|---|---|---|",
        ]
        for result in longClips {
            let goal = result.transcribeSeconds <= Self.goalSeconds ? "met" : "not met"
            let audio = seconds(result.clip.seconds)
            let cells = [result.clip.id, audio, seconds(result.detectSeconds), seconds(result.transcribeSeconds), goal]
            lines.append("| " + cells.joined(separator: " | ") + " |")
        }
        return lines + [""]
    }

    private var clipSection: [String] {
        var lines = [
            "## Clips", "",
            "| Clip | Source | Language | Detected | Share of ru/en/ko | CER |", "|---|---|---|---|---|---|",
        ]
        for result in results {
            let probability = result.probability.map { String(format: "%.2f", $0) } ?? "-"
            let cells = [
                result.clip.id, result.clip.source.rawValue, result.clip.language.rawValue,
                result.detected?.rawValue ?? "none", probability, percent(result.characterErrorRate),
            ]
            lines.append("| " + cells.joined(separator: " | ") + " |")
        }
        return lines + [""]
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.1f %%", value * 100)
    }

    private func seconds(_ value: Double) -> String {
        String(format: "%.2f s", value)
    }

    private static var machine: String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var brand = [UInt8](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
        let name = String(bytes: brand.prefix { $0 != 0 }, encoding: .utf8) ?? "unknown CPU"
        return "\(name), macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
    }
}
