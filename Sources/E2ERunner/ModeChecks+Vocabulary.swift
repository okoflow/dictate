import AppKit
import DictateCore
import Foundation

/// The M5 checks: the personal dictionary, snippets, the history file and a per-app mode.
extension ModeChecks {
    private static let snippetText = "ivan.petrov@example.com"
    private static let vocabulary = Vocabulary(
        terms: [
            .init(term: "Kubernetes", spoken: ["кубернетис", "кубернетес", "кубернитис"]),
            .init(term: "WhisperKit", spoken: ["whisper kit", "whisper-kit"]),
        ],
        snippets: [.init(trigger: "моя почта", text: snippetText)]
    )

    /// Each vocabulary fixture first with an empty dictionary (what Whisper writes on its own), then with the
    /// dictionary: the term must come out as written there. "Моя почта" must become the snippet text, as it is,
    /// in any mode. Every delivered text must be in the history file, newest last.
    func dictionaryAndSnippets() -> Outcome {
        run {
            try writeDictionary(.empty)
            var notes: [String] = []
            for (id, term) in [("ru-vocab-1", "Kubernetes"), ("en-vocab-1", "WhisperKit")] {
                let before = try dictate(id, mode: .raw)
                try writeDictionary(Self.vocabulary)
                let after = try dictate(id, mode: .raw)
                guard after.text.contains(term) else {
                    throw Verdict.fail("\(id): \"\(after.text)\" has no \(term) (Whisper heard \"\(after.raw)\")")
                }
                let rate = TextMetrics.cer(
                    reference: after.fixture.clean ?? after.fixture.text, hypothesis: after.text, language: after.fixture.language
                )
                guard rate <= ModeChecks.maximumLightErrorRate else {
                    throw Verdict.fail(String(format: "\(id): \"\(after.text)\" is off by %.0f %%", rate * 100))
                }
                let how = after.raw.contains(term) ? "recognised" : "corrected"
                let without = before.text.contains(term) ? "right" : "\"\(before.text)\""
                notes.append("\(term) \(how) (without the dictionary: \(without))")
                try writeDictionary(.empty)
            }
            try writeDictionary(Self.vocabulary)
            for mode in [Mode.raw, .light] {
                let snippet = try dictate("ru-snippet-1", mode: mode)
                guard snippet.text == Self.snippetText else {
                    throw Verdict.fail("\(mode): \"\(snippet.raw)\" became \"\(snippet.text)\", expected the snippet")
                }
            }
            try requireHistoryEndsWith(Self.snippetText)
            return .measured(notes.joined(separator: "; ") + "; snippet expanded; history kept")
        }
    }

    /// Chrome in front, Dictate in Raw, Chrome's own mode Light: the dictation must be processed in Light (and is
    /// not pasted: the suite pastes only into TestPad).
    func appModeInChrome() -> Outcome {
        run {
            guard let chromeURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.chrome) else {
                throw Verdict.blocked("Google Chrome is not installed")
            }
            RunLoop.current.run(mode: .default, before: Date())
            let previous = NSWorkspace.shared.frontmostApplication?.bundleURL
            try open(chromeURL)
            // Back to where you were, so later checks (and you) do not dictate into Chrome.
            defer {
                if let previous, previous != chromeURL {
                    try? open(previous)
                }
            }
            let baseline = log.baseline()
            let delivery = try dictate("ru-filler-1", mode: .raw, processedIn: .light)
            guard log.newEvents(since: baseline).contains(.appModeUsed(app: Self.chrome, mode: .light)) else {
                throw Verdict.fail("Chrome's own mode was not used: \(log.newEvents(since: baseline))")
            }
            try requireLight(delivery)
            return .measured("Chrome → Light while the menu says Raw")
        }
    }

    // MARK: Helpers

    private func writeDictionary(_ vocabulary: Vocabulary) throws {
        do {
            try JSONEncoder().encode(vocabulary).write(to: dictionaryURL, options: .atomic)
        } catch {
            throw Verdict.fail("cannot write the dictionary file: \(error)")
        }
        // The app notices a new file by its modification date.
        Thread.sleep(forTimeInterval: 0.05)
    }

    private func requireHistoryEndsWith(_ text: String) throws {
        guard let data = try? Data(contentsOf: historyURL),
              let history = try? JSONDecoder().decode(DictationHistory.self, from: data)
        else { throw Verdict.fail("no history file at \(historyURL.path)") }
        guard history.entries.last?.text == text, history.entries.count >= 2 else {
            throw Verdict.fail("the history ends with \"\(history.entries.last?.text ?? "nothing")\", expected \"\(text)\"")
        }
    }

    /// Opens (activates) the app and waits until it is in front.
    private func open(_ app: URL) throws {
        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = [app.path]
        try? open.run()
        open.waitUntilExit()
        let inFront = waitUntil(timeout: 10, interval: 0.2) {
            RunLoop.current.run(mode: .default, before: Date())
            return NSWorkspace.shared.frontmostApplication?.bundleURL == app
        }
        guard inFront else {
            throw Verdict.blocked("macOS did not bring \(app.lastPathComponent) to the front (you may be using another app)")
        }
    }
}
