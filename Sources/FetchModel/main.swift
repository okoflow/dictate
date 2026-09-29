import DictateCore
import Foundation
import Transcription

// `make model`: downloads the speech model (unless it is there), then loads it once. The first load
// makes Core ML compile the model for this Mac (about a minute) and fetches the tokenizer, so
// everything that runs afterwards (the app, `make e2e`, `make bench`) starts fast and offline.
// Usage: FetchModel [--model <variant>]

let model = argumentValue(after: "--model") ?? ModelStore.defaultModel
let base = ModelStore.defaultBaseDirectory
print("model \(model)\nfolder \(ModelStore.folder(of: model, in: base).path)")

if ModelStore.isInstalled(model, in: base) {
    print("already downloaded")
} else {
    let reporter = ProgressReporter()
    do {
        try await Transcriber.download(model: model, into: base) { reporter.report($0) }
    } catch {
        print("download failed: \(error)")
        exit(1)
    }
    print("\ndownloaded")
}

do {
    let seconds = try await Transcriber(model: model, baseDirectory: base).load()
    print(String(format: "loaded in %.1f s; the model is ready", seconds))
} catch {
    print("load failed: \(error)")
    exit(1)
}

/// Prints a line every 5 %, which is readable in a terminal and in a log.
final class ProgressReporter: @unchecked Sendable {
    private let lock = NSLock()
    private var lastStep = -1

    func report(_ fraction: Double) {
        let step = Int(fraction * 100) / 5
        lock.lock()
        defer { lock.unlock() }
        guard step > lastStep else { return }
        lastStep = step
        print("downloading \(step * 5) %")
    }
}
