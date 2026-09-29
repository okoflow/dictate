import DictateCore
import Foundation

/// The app's `--event-log` file, plus a snapshot taken before an action so a check reacts only to
/// what that action caused and never to leftovers from an earlier check.
struct EventLog {
    struct Baseline {
        let eventCount: Int
        let files: Set<String>
    }

    let url: URL
    let recordingDirectory: URL

    var events: [AppEvent] {
        (try? String(contentsOf: url, encoding: .utf8)).map(AppEvent.parseLog) ?? []
    }

    func baseline() -> Baseline {
        Baseline(eventCount: events.count, files: recordingFiles())
    }

    func newEvents(since baseline: Baseline) -> [AppEvent] {
        Array(events.dropFirst(baseline.eventCount))
    }

    /// Finished `.wav` files only; a `.tmp` is a recording still being written.
    func newFiles(since baseline: Baseline) -> Set<String> {
        recordingFiles().subtracting(baseline.files)
    }

    /// Waits for a new event for which `match` returns a value.
    func waitForNew<T>(since baseline: Baseline, timeout: TimeInterval, _ match: (AppEvent) -> T?) -> T? {
        var found: T?
        _ = waitUntil(timeout: timeout, interval: 0.01) {
            found = newEvents(since: baseline).lazy.compactMap(match).first
            return found != nil
        }
        return found
    }

    /// Waits for a new event satisfying `predicate`.
    func waitFor(since baseline: Baseline, timeout: TimeInterval, where predicate: (AppEvent) -> Bool) -> Bool {
        waitForNew(since: baseline, timeout: timeout) { predicate($0) ? $0 : nil } != nil
    }

    private func recordingFiles() -> Set<String> {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: recordingDirectory.path)) ?? []
        return Set(names.filter { $0.hasSuffix(".wav") })
    }
}
