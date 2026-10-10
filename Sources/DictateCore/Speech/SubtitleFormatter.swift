import Foundation

package enum SubtitleFormatter {
    private struct Cue {
        var start: TimeInterval
        var end: TimeInterval
        let lines: [String]
    }

    private static let lineLength = 42
    private static let pauseMarks: Set<Character> = [",", ".", ";", ":", "!", "?", "…", "、", "。", "，", "！", "？", "；", "："]
    private static let compactLineLength = 18

    package static func srt(_ transcript: TimedTranscript) -> String {
        var timeline: [Cue] = []

        for segment in transcript.segments {
            for var cue in cues(for: segment, language: transcript.language) {
                cue.start = max(cue.start, timeline.last?.end ?? 0)
                cue.end = max(cue.end, cue.start)
                timeline.append(cue)
            }
        }

        return timeline.enumerated().map { index, cue in
            "\(index + 1)\n\(timestamp(cue.start)) --> \(timestamp(cue.end))\n\(cue.lines.joined(separator: "\n"))\n"
        }
        .joined(separator: "\n")
    }

    private static func cues(for segment: TimedSegment, language: Language) -> [Cue] {
        let isSpaced = language.separatesWordsWithSpaces
        let limit = isSpaced ? lineLength : compactLineLength
        let joiner = isSpaced ? " " : ""
        let units = isSpaced ? segment.text.split(separator: " ").map(String.init) : segment.text.map(String.init)
        let total = units.joined(separator: joiner).count
        let count = max(1, Int((Double(total) / Double(limit * 2)).rounded(.up)))
        var start = segment.start
        var consumed = 0

        return groups(of: units, count: count, joiner: joiner).map { group in
            consumed += group.joined(separator: joiner).count
            let end = segment.start + (segment.end - segment.start) * Double(consumed) / Double(max(1, total))
            let cue = Cue(start: start, end: end, lines: lines(of: group, limit: limit, joiner: joiner))
            start = end

            return cue
        }
    }

    private static func groups(of units: [String], count: Int, joiner: String) -> [[String]] {
        let ends = endPositions(of: units, joiner: joiner)
        let total = Double(ends.last ?? 0)
        var breaks: [Int] = []

        for part in 1 ..< max(1, count) {
            let target = total * Double(part) / Double(count)
            let earliest = (breaks.last ?? 0) + 1
            guard earliest < units.count else { break }

            breaks.append(bestBreak(in: earliest ..< units.count, ends: ends, units: units, target: target))
        }

        var groups: [[String]] = []
        var lower = 0

        for upper in breaks + [units.count] where upper > lower {
            groups.append(Array(units[lower ..< upper]))
            lower = upper
        }

        return groups
    }

    private static func lines(of units: [String], limit: Int, joiner: String) -> [String] {
        let text = units.joined(separator: joiner)
        guard text.count > limit, units.count > 1 else { return [text] }

        let ends = endPositions(of: units, joiner: joiner)
        let split = bestBreak(in: 1 ..< units.count, ends: ends, units: units, target: Double(text.count) / 2)

        return [units[..<split].joined(separator: joiner), units[split...].joined(separator: joiner)]
    }

    private static func endPositions(of units: [String], joiner: String) -> [Int] {
        var length = 0

        return units.enumerated().map { index, unit in
            length += (index == 0 ? 0 : joiner.count) + unit.count

            return length
        }
    }

    private static func bestBreak(in candidates: Range<Int>, ends: [Int], units: [String], target: Double) -> Int {
        candidates.min { first, second in
            score(first, ends: ends, units: units, target: target) < score(second, ends: ends, units: units, target: target)
        } ?? candidates.lowerBound
    }

    private static func score(_ index: Int, ends: [Int], units: [String], target: Double) -> Double {
        let distance = abs(Double(ends[index - 1]) - target)
        let followsPause = units[index - 1].last.map { pauseMarks.contains($0) } ?? false

        return followsPause ? distance - 10 : distance
    }

    private static func timestamp(_ time: TimeInterval) -> String {
        let total = Int((max(0, time) * 1000).rounded())

        return String(format: "%02d:%02d:%02d,%03d", total / 3_600_000, total / 60000 % 60, total / 1000 % 60, total % 1000)
    }
}
