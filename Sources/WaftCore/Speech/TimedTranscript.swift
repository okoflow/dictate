import Foundation

package struct TimedTranscript: Equatable, Sendable {
    private static let paragraphPause: TimeInterval = 2

    package let language: Language
    package let segments: [TimedSegment]

    package var duration: TimeInterval {
        segments.last?.end ?? 0
    }

    package var text: String {
        var paragraphs: [[String]] = []
        var previousEnd: TimeInterval?

        for segment in segments {
            if let previousEnd, segment.start - previousEnd < Self.paragraphPause, !paragraphs.isEmpty {
                paragraphs[paragraphs.count - 1].append(segment.text)
            } else {
                paragraphs.append([segment.text])
            }

            previousEnd = segment.end
        }

        let separator = language.separatesWordsWithSpaces ? " " : ""

        return paragraphs.map { $0.joined(separator: separator) }.joined(separator: "\n\n")
    }

    package init(language: Language, segments: [TimedSegment]) {
        self.language = language
        self.segments = segments
    }
}
