import Foundation

enum Outcome {
    case pass
    case fail(String)
    /// Cannot run until the user grants something (a permission, a tool). Not a code defect.
    case blocked(String)

    var label: String {
        switch self {
        case .pass: "PASS"
        case .fail: "FAIL"
        case .blocked: "BLOCKED"
        }
    }

    var detail: String? {
        switch self {
        case .pass: nil
        case let .fail(message), let .blocked(message): message
        }
    }
}

struct CheckResult {
    let name: String
    let outcome: Outcome
    let seconds: Double
}

struct Report {
    let results: [CheckResult]
    let date: Date

    var failed: Bool {
        results.contains {
            if case .fail = $0.outcome {
                true
            } else {
                false
            }
        }
    }

    var blocked: Bool {
        results.contains {
            if case .blocked = $0.outcome {
                true
            } else {
                false
            }
        }
    }

    /// 0 = everything passed, 1 = a check failed, 2 = nothing failed but some checks wait for the user.
    var exitCode: Int32 {
        if failed {
            return 1
        }
        if blocked {
            return 2
        }
        return 0
    }

    var markdown: String {
        var lines = ["# E2E report", "", "Run: \(date.formatted(.iso8601))", ""]
        lines += ["| Check | Result | Time | Detail |", "|---|---|---|---|"]
        for result in results {
            let detail = (result.outcome.detail ?? "").replacingOccurrences(of: "\n", with: " ")
            lines.append("| \(result.name) | \(result.outcome.label) | \(String(format: "%.1fs", result.seconds)) | \(detail) |")
        }
        let verdict = switch exitCode {
        case 0: "**GREEN**"
        case 2: "**BLOCKED** — no failures, but some checks need your action (see Detail)."
        default: "**RED**"
        }
        lines += ["", verdict, ""]
        return lines.joined(separator: "\n")
    }

    func save(in directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: date)
        let url = directory.appendingPathComponent("\(stamp).md")
        try markdown.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
